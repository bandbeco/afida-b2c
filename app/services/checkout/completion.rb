module Checkout
  # Checkout completion (see CONTEXT.md): turns a paid Checkout Session into
  # exactly one Order with its invariant side effects, whichever completion
  # channel (the success redirect or the Stripe webhook) arrives first. The
  # other channel finds the order and does nothing.
  #
  # The channels keep only transport: the redirect its flash, redirect and
  # browser-session cleanup, the webhook the HTTP status Stripe sees and its own
  # webhook.* tracing events. Everything a completion means lives here:
  #   - the retrieve, with the expands the money and address reads depend on
  #   - the paid check (COMPLETED_PAYMENT_STATUSES)
  #   - the exactly-once order row: an existing order is found before any
  #     Stripe call, and the create race between channels is absorbed
  #   - consuming the cart inside the order's transaction (OrderCreator)
  #   - the side effects (CompletionEffects)
  #   - reporting to Sentry, once, whichever channel hit the failure
  #
  # Interface: .complete(session_id, browser_present:) returns an Outcome whose
  # status is :created (this call made the order and fired the effects),
  # :existing (an earlier completion did) or :unpaid (no order; the session has
  # not been paid, or is not a payment-mode session at all). It raises
  # PermanentCompletionFailure when the session can never produce an order and
  # TransientCompletionFailure when a retry may succeed. Anything else (a
  # programmer error) propagates untouched.
  #
  # Effects run after the order commits and are reported, not retried: a crash
  # between the commit and the effects loses them, since the retry finds the
  # order and returns :existing. A durable marker is a known follow-up.
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
      # from the id alone, so no Stripe call is made and the answer does not
      # depend on Stripe being up.
      if (existing = Order.find_by(stripe_session_id: @session_id))
        return Outcome.new(order: existing, status: :existing)
      end

      session = retrieve_session
      return Outcome.new(order: nil, status: :unpaid) unless payment?(session) && paid?(session)

      order, created = create_order(session)
      return Outcome.new(order: order, status: :existing) unless created

      report_itemless(order, session) if order.order_items.none?
      effects_for(order, session).run
      Outcome.new(order: order, status: :created)
    rescue Stripe::InvalidRequestError => e
      # A session id Stripe cannot resolve fails identically on every retry.
      # Stripe raises the same class for retryable conditions too (lock_timeout),
      # so only resource_missing is permanent.
      e.code == "resource_missing" ? fail_permanent(e) : fail_transient(e)
    rescue Stripe::StripeError => e
      fail_transient(e)
    rescue Checkout::PermanentCompletionFailure => e
      report("can never complete", e)
      raise
    end

    private

    # [order, created]. created is false when this call lost the create race:
    # the other channel committed in the window after our find_by, so create!
    # hit the unique stripe_session_id index or the model validation ahead of
    # it, and the pair carries that order instead. Any other RecordInvalid (an
    # item rollback) leaves no order, and a retry may fix it. Rescued only
    # around the create so a failure elsewhere is never mistaken for a lost race.
    def create_order(session)
      [ OrderCreator.new(stripe_session: session, cart: cart_for(session)).create, true ]
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      existing = Order.find_by(stripe_session_id: @session_id)
      return [ existing, false ] if existing

      fail_transient(e)
    end

    private

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

    # A static message so Sentry groups every item-less order into one issue;
    # the ids ride in extra.
    def report_itemless(order, session)
      Rails.logger.warn("[Checkout completion] Order #{order.id} recorded without line items " \
                        "(cart_id: #{metadata_value(session, "cart_id").inspect}); reconcile against session #{session.id}")
      Sentry.capture_message("Checkout completion recorded an order without line items", level: :warning,
        extra: { order_id: order.id, stripe_session_id: session.id, cart_id: metadata_value(session, "cart_id") })
    end

    def effects_for(order, session)
      CompletionEffects.new(order,
        browser_present: @browser_present,
        payment_method: Checkout::SessionDetails.payment_method_type(session),
        welcome_discount_code: metadata_value(session, "discount_code"),
        datafast_visitor_id: metadata_value(session, "datafast_visitor_id"),
        datafast_session_id: metadata_value(session, "datafast_session_id")
      )
    end

    def fail_permanent(cause)
      report("can never complete", cause)
      raise Checkout::PermanentCompletionFailure, cause.message
    end

    def fail_transient(cause)
      report("failed, retryable", cause)
      raise Checkout::TransientCompletionFailure, cause.message
    end

    # One log line and one Sentry capture per failure, whichever channel hit it.
    def report(outcome, error)
      Rails.logger.error("[Checkout completion] session #{@session_id} #{outcome}: #{error.class}: #{error.message}")
      Sentry.capture_exception(error, extra: { stripe_session_id: @session_id })
    end
  end
end
