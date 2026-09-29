module Checkout
  # The side effects of a checkout completion (see CONTEXT.md): what fires once
  # an Order exists, whichever completion channel created it. Kept apart from
  # the Stripe session so "which effects fire on completion" is asserted against
  # an Order plus plain facts, and so a future non-session completion (a
  # reorder) can reuse it. Internal to the Checkout namespace: Completion is
  # its only caller today.
  #
  # Effects are independent and each is attempted even if another fails: the
  # order has already committed, and a webhook retry would find it and do
  # nothing, so raising here could only lose the remaining effects. A failed
  # effect is reported to Sentry instead.
  #
  # The one channel-dependent effect is the GA4 purchase. The confirmation page
  # fires it client-side with the real client id and consent state (see
  # OrdersController#confirmation), so the server-side call, which uses a
  # synthetic client id, is a fallback for a customer who is not in a browser.
  #
  # welcome_discount_code is the Welcome discount as SessionBuilder recorded it
  # in Stripe metadata: present only when the discount was actually applied.
  # KlaviyoSubscriber resolves the customer email from order_id (Rails.event
  # filters payload[:email]), so order_id is the contract on every event.
  class CompletionEffects
    def initialize(order, browser_present:, payment_method: nil, welcome_discount_code: nil,
                   datafast_visitor_id: nil, datafast_session_id: nil)
      @order = order
      @browser_present = browser_present
      @payment_method = payment_method
      @welcome_discount_code = welcome_discount_code.presence
      @datafast_visitor_id = datafast_visitor_id.presence
      @datafast_session_id = datafast_session_id.presence
    end

    def run
      attempt("confirmation emails") do
        OrderMailer.with(order: order).confirmation_email.deliver_later
        OrderMailer.with(order: order).ops_confirmation_email.deliver_later
      end
      attempt("team notification") { TelegramOrderNotificationJob.perform_later(order.id) }
      attempt("GA4 fallback") { Ga4MeasurementProtocolService.track_purchase(order) } unless browser_present
      attempt("events") { notify_events }
    end

    private

    attr_reader :order, :browser_present, :payment_method, :welcome_discount_code,
                :datafast_visitor_id, :datafast_session_id

    def notify_events
      set_datafast_context

      Rails.event.notify("checkout.completed",
        order_id: order.id,
        total: order.total_amount.to_f,
        payment_method: payment_method
      )

      Rails.event.notify("order.placed",
        order_id: order.id,
        email: order.email,
        total: order.total_amount.to_f,
        item_count: order.order_items.count,
        has_discount: welcome_discount_code.present?,
        source: "checkout"
      )

      return unless welcome_discount_code

      Rails.event.notify("email_signup.discount_claimed",
        email: order.email,
        order_id: order.id,
        discount_code: welcome_discount_code
      )
    end

    # The Datafast visitor who paid, as captured at session creation. Merged into
    # the current event context (set_context merges), so on the redirect channel
    # request_id and user_id survive and on the webhook channel, which has no
    # browser cookies, the conversion still attributes to the right visitor.
    def set_datafast_context
      return unless datafast_visitor_id

      Rails.event.set_context(
        datafast_visitor_id: datafast_visitor_id,
        datafast_session_id: datafast_session_id
      )
    end

    def attempt(name)
      yield
    rescue StandardError => e
      Rails.logger.error("[Checkout completion] #{name} failed for order #{order.id}: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, extra: { order_id: order.id, effect: name })
    end
  end
end
