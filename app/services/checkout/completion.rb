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
  # not been paid). It raises PermanentCompletionFailure when the session can
  # never produce an order and TransientCompletionFailure when a retry may
  # succeed. Anything else (a programmer error) propagates untouched.
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
      return Outcome.new(order: nil, status: :unpaid) unless paid?(session)

      order = OrderCreator.new(stripe_session: session, cart: cart_for(session)).create
      report_itemless(order, session) if order.order_items.none?
      effects_for(order, session).run
      Outcome.new(order: order, status: :created)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Lost the create race: the other channel committed the order in the window
      # after our find_by, so create! hit the unique stripe_session_id index (or
      # the model validation ahead of it). Benign: the order exists. If it does
      # not, the constraint or validation fired for another reason (an item
      # rollback), which a retry may fix.
      existing = Order.find_by(stripe_session_id: @session_id)
      return Outcome.new(order: existing, status: :existing) if existing

      fail_transient(e)
    rescue Stripe::StripeError => e
      fail_transient(e)
    rescue Checkout::PermanentCompletionFailure => e
      Rails.logger.error("[Checkout completion] session #{@session_id} can never complete: #{e.message}")
      Sentry.capture_exception(e, extra: { stripe_session_id: @session_id })
      raise
    end

    private

    def retrieve_session
      Stripe::Checkout::Session.retrieve(id: @session_id, expand: EXPAND)
    end

    def paid?(session)
      Checkout::COMPLETED_PAYMENT_STATUSES.include?(session.payment_status)
    end

    # The cart the session was priced from, named in metadata since 2026-05.
    # Nil when it has gone (the order is still recorded, see OrderCreator).
    def cart_for(session)
      cart_id = session.metadata&.[]("cart_id")
      Cart.find_by(id: cart_id) if cart_id.present?
    end

    def report_itemless(order, session)
      message = "[Checkout completion] Order #{order.id} recorded without line items " \
                "(cart_id: #{session.metadata&.[]("cart_id").inspect}); reconcile against session #{session.id}"
      Rails.logger.warn(message)
      Sentry.capture_message(message, level: :warning, extra: { order_id: order.id, stripe_session_id: session.id })
    end

    def effects_for(order, session)
      metadata = session.metadata
      CompletionEffects.new(order,
        browser_present: @browser_present,
        payment_method: Checkout::SessionDetails.payment_method_type(session),
        welcome_discount_code: metadata&.[]("discount_code"),
        datafast_visitor_id: metadata&.[]("datafast_visitor_id"),
        datafast_session_id: metadata&.[]("datafast_session_id")
      )
    end

    def fail_transient(cause)
      Rails.logger.error("[Checkout completion] session #{@session_id} failed, retryable: #{cause.class}: #{cause.message}")
      Sentry.capture_exception(cause, extra: { stripe_session_id: @session_id })
      raise Checkout::TransientCompletionFailure, cause.message
    end
  end
end
