module Checkout
  # Checkout completion (see CONTEXT.md): turns a paid Checkout Session into
  # exactly one Order with its invariant side effects, whichever completion
  # channel (the success redirect or the Stripe webhook) arrives first. The
  # other channel finds the order. Effects run once, on whichever channel
  # finds them still unrecorded.
  #
  # The channels keep only transport: the redirect its flash, redirect and
  # browser-session cleanup, the webhook the HTTP status Stripe sees and its own
  # webhook.* tracing events. Everything a completion means lives here:
  #   - the retrieve, with the expands the money and address reads depend on
  #   - the paid check (COMPLETED_PAYMENT_STATUSES)
  #   - the exactly-once order row: an existing order is found before any
  #     Stripe call, and the create race between channels is absorbed
  #   - consuming the cart inside the order's transaction (OrderCreator)
  #   - the side effects (CompletionEffects), recorded on effects_completed_at
  #   - reporting to Sentry, once, whichever channel hit the failure
  #
  # Interface: .complete(session_id, browser_present:) returns an Outcome whose
  # status is :created (this call inserted the order), :existing (the row was
  # already there) or :unpaid (no order; the session has not been paid, or is
  # not a payment-mode session at all). Effects run for a :created order and
  # for an :existing order whose effects_completed_at is still nil. It raises
  # PermanentCompletionFailure when the session can never produce an order and
  # TransientCompletionFailure when a retry may succeed. Anything else (a
  # programmer error, including an exception that escapes the effects before
  # they are recorded) propagates untouched, so the webhook answers 5xx and
  # Stripe retries.
  #
  # effects_completed_at is set only after the effects finish, under a row
  # lock. A crash between the commit and that write leaves the marker nil,
  # and the next channel runs the effects. The lock keeps the redirect and
  # the webhook from both sending. A failure rescued inside one effect does
  # not withhold the marker: that effect is already in Sentry, and running
  # the set again would repeat the effects that succeeded (a second
  # confirmation email, a second order.placed). No background job: the
  # effects are already mostly enqueues, and the two channels are the retry.
  #
  # browser_present says whether the customer is looking at the site right now:
  # true on the redirect, false on the webhook. It decides only the GA4
  # server-side fallback (see CompletionEffects).
  class Completion
    # total_details.breakdown is omitted unless expanded, and without it the
    # discount breakdown is nil, so the promotion code cannot be read and the
    # order records no discount_code. The nested price.product is what lets
    # SessionAmounts identify the shipping line by its metadata.
    EXPAND = [ "collected_information", "line_items.data.price.product",
               "payment_intent.payment_method", "total_details.breakdown" ].freeze

    Outcome = Data.define(:order, :status) do
      def created? = status == :created
      def existing? = status == :existing
      def unpaid? = status == :unpaid
    end

    def self.complete(session_id, browser_present:)
      new(session_id, browser_present: browser_present).complete
    end

    def initialize(session_id, browser_present:)
      @session_id = session_id
      @browser_present = browser_present
    end

    def complete
      # The common case: the other channel already completed this session. Found
      # from the id alone, so when its effects are already recorded no Stripe
      # call is made and the answer does not depend on Stripe being up. When
      # the marker is still nil (a crash after the commit), this channel
      # finishes the effects.
      if (existing = Order.find_by(stripe_session_id: @session_id))
        ensure_effects(existing)
        return Outcome.new(order: existing, status: :existing)
      end

      session = retrieve_session
      @retrieved_session = session
      return Outcome.new(order: nil, status: :unpaid) unless payment?(session) && paid?(session)

      order, created = create_order(session)
      ensure_effects(order, session)
      Outcome.new(order: order, status: created ? :created : :existing)
    rescue Checkout::PermanentCompletionFailure => e
      # Body-raised permanent failures (missing shipping, an unexpanded line
      # item) are reported here and re-raised as themselves, so callers can
      # still tell MissingShippingDetails apart. fail_permanent marks the
      # exception it raises, so a validation failure is not reported twice.
      report_permanent(e, session_for(e)) unless e.already_reported
      raise
    rescue Stripe::InvalidRequestError => e
      # A session id Stripe cannot resolve fails identically on every retry.
      # Stripe raises the same class for retryable conditions too (lock_timeout),
      # so only resource_missing is permanent.
      e.code == "resource_missing" ? fail_permanent(e, session: nil) : fail_transient(e)
    rescue Stripe::StripeError => e
      fail_transient(e)
    end

    # [order, created]. created is false when this call lost the create race:
    # the other channel committed in the window after our find_by, so create!
    # hit the unique stripe_session_id index or the model validation ahead of
    # it, and the pair carries that order instead. RecordNotUnique or a lost-race
    # RecordInvalid (unique index validated by the model) both leave an existing
    # order. Any other RecordInvalid is classified by type: Order validation
    # failures (invalid data) are permanent (a retry cannot fix them), while
    # nested association failures remain transient for backwards compatibility.
    # Rescued only around the create so a failure elsewhere is never mistaken for a race.
    def create_order(session)
      [ OrderCreator.new(stripe_session: session, cart: cart_for(session)).create, true ]
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      existing = Order.find_by(stripe_session_id: @session_id)
      return [ existing, false ] if existing

      # No existing order: distinguish deterministic from transient failures.
      # Order validation errors are deterministic (invalid email, missing fields);
      # nested association rollbacks may be transient (kept for compatibility).
      if e.is_a?(ActiveRecord::RecordInvalid) && e.record.is_a?(Order)
        fail_permanent(e, session: session)
      else
        fail_transient(e)
      end
    end

    private

    # One sender for this order's effects. The row lock is the claim: the
    # other channel blocks until this transaction commits the marker or rolls
    # back. The session is retrieved before the lock so that Stripe
    # round-trip does not hold the row. An exception from run aborts the
    # transaction before the marker is committed, so a crash stays retryable.
    def ensure_effects(order, session = nil)
      return if order.effects_completed_at.present?

      unless session
        session = retrieve_session
        @retrieved_session = session
      end

      order.with_lock do
        next if order.effects_completed_at.present?

        itemless = order.order_items.none?
        handle_itemless_order(order, session) if itemless
        effects_for(order, session, itemless: itemless).run
        order.update_columns(effects_completed_at: Time.current)
      end
    end

    def retrieve_session
      Stripe::Checkout::Session.retrieve(id: @session_id, expand: EXPAND)
    end

    # Only payment-mode sessions are checkouts. Stripe also completes setup-mode
    # sessions (reorder card capture) as no_payment_required; they carry no
    # order and must not be reported as completions that failed.
    def payment?(session)
      session.mode == "payment"
    end

    def paid?(session)
      Checkout::COMPLETED_PAYMENT_STATUSES.include?(session.payment_status)
    end

    # The cart the session was priced from, named in metadata since 2026-05.
    # Nil when it has gone (the order is still recorded, see OrderCreator).
    def cart_for(session)
      cart_id = metadata_value(session, "cart_id")
      Cart.find_by(id: cart_id) if cart_id.present?
    end

    def metadata_value(session, key)
      session.metadata&.[](key)
    end

    # When a paid order has no items (the cart is gone or mismatched), report it
    # for ops to reconcile and suppress the normal customer confirmation email.
    # The ops confirmation still fires (see CompletionEffects#run with itemless: true).
    def handle_itemless_order(order, session)
      Rails.logger.error("[Checkout completion] Order #{order.id} recorded without line items " \
                        "(cart_id: #{metadata_value(session, "cart_id").inspect}); reconcile against session #{session.id}")
      Sentry.capture_message("Checkout completion recorded an order without line items", level: :error,
        extra: {
          order_id: order.id,
          stripe_session_id: session.id,
          cart_id: metadata_value(session, "cart_id"),
          session_line_item_count: session.line_items&.data&.size || 0,
          session_amount_total: session.amount_total
        })
    end

    def effects_for(order, session, itemless: false)
      CompletionEffects.new(order,
        browser_present: @browser_present,
        payment_method: Checkout::SessionDetails.payment_method_type(session),
        welcome_discount_code: metadata_value(session, "discount_code"),
        datafast_visitor_id: metadata_value(session, "datafast_visitor_id"),
        datafast_session_id: metadata_value(session, "datafast_session_id"),
        itemless: itemless
      )
    end

    def fail_permanent(cause, session:)
      report_permanent(cause, session)
      error = Checkout::PermanentCompletionFailure.new(cause.message)
      error.already_reported = true
      raise error
    end

    # One report for a permanent failure, with the validation errors and the
    # Stripe session fields ops need to recreate the order by hand.
    def report_permanent(cause, session)
      extra = { stripe_session_id: @session_id }

      if cause.is_a?(ActiveRecord::RecordInvalid) && cause.record.is_a?(Order)
        extra[:validation_errors] = cause.record.errors.messages
      end

      if session
        extra[:customer_email] = session.customer_details&.email
        extra[:session_amount_total] = session.amount_total
        extra[:session_line_items_summary] = summarize_line_items(session)
      end

      report("can never complete", cause, level: :error, extra: extra)
    end

    def session_for(error)
      return error.stripe_session if error.respond_to?(:stripe_session) && error.stripe_session

      @retrieved_session
    end

    def fail_transient(cause)
      report("failed, retryable", cause)
      raise Checkout::TransientCompletionFailure, cause.message
    end

    # One log line and one Sentry capture per failure, whichever channel hit it.
    def report(outcome, error, level: :warning, extra: {})
      Rails.logger.error("[Checkout completion] session #{@session_id} #{outcome}: #{error.class}: #{error.message}")
      Sentry.capture_exception(error, level: level, extra: extra.merge(stripe_session_id: @session_id))
    end

    # Summarize line items for Sentry reporting (for recreating orders by hand)
    def summarize_line_items(session)
      return [] unless session.line_items&.data

      session.line_items.data.map do |item|
        {
          description: item.description,
          quantity: item.quantity,
          amount_subtotal: item.amount_subtotal,
          amount_total: item.amount_total
        }
      end
    end
  end
end
