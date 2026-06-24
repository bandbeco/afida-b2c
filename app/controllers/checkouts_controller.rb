class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: "Too many checkout attempts. Please wait before trying again." }

  # Stripe completes a payment-mode session as "paid" normally, or
  # "no_payment_required" when a discount (e.g. a 100%-off coupon) brings the
  # total to 0. Both are successful completions and must yield an order; only
  # "unpaid" should be rejected.
  COMPLETED_PAYMENT_STATUSES = %w[paid no_payment_required].freeze

  def create
    cart = Current.cart
    # Kept outside the begin block so the rescue path can inspect builder state
    # after Stripe raises during session creation.
    builder = nil

    begin
      # Emit checkout.started event for funnel tracking
      Rails.event.notify("checkout.started",
        cart_id: cart.id,
        item_count: cart.cart_items.count,
        subtotal: cart.subtotal_amount
      )

      # Abandoned-cart trigger for logged-in users. Guests fire this from the
      # discount-signup form; logged-in users have no such form moment (repeat
      # customers never see it), so we fire here where Current.user and the cart
      # coexist. KlaviyoSubscriber resolves the email from user_id (payload[:email]
      # is filtered). Skip when a discount code is set: the form already fired the
      # trigger this session, and we don't want a duplicate. Sample-only carts are
      # excluded (zero value), mirroring order.placed's sample handling.
      # The discount_code de-dupe is session-scoped, so a cross-device form-then-
      # checkout can still fire twice; Klaviyo's Flow dedupes the actual send.
      # Fires before SessionBuilder by design (like checkout.started above): a
      # later Stripe failure still counts as intent, and the Flow's "Placed Order
      # zero times" filter suppresses the email if they never complete.
      if Current.user && cart.cart_items.any? && !cart.only_samples? && session[:discount_code].blank?
        Rails.event.notify("cart.checkout_initiated",
          cart_id: cart.id,
          user_id: Current.user.id,
          source: "checkout"
        )
      end

      builder = Checkout::SessionBuilder.new(
        cart: cart,
        user: Current.user,
        address_id: params[:address_id],
        discount_code: session[:discount_code],
        datafast_visitor_id: cookies[:datafast_visitor_id],
        datafast_session_id: cookies[:datafast_session_id],
        success_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancel_checkout_url
      )
      result = builder.create

      if result.invalid_discount?
        session.delete(:discount_code)
        flash[:alert] = "Your discount code could not be applied. Please continue with your order."
      end

      session[:selected_address_id] = result.selected_address_id if result.selected_address_id.present?

      redirect_to result.session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      session.delete(:discount_code) if builder&.invalid_discount?
      Rails.logger.error("Stripe error: #{e.message}")
      flash[:error] = e.message
      redirect_to cart_path
    end
  end

  def success
    session_id = params[:session_id]

    unless session_id.present?
      flash[:error] = "Invalid checkout session"
      return redirect_to cart_path
    end

    begin
      stripe_session = Stripe::Checkout::Session.retrieve(
        id: session_id,
        expand: [ "collected_information", "line_items.data.price.product" ]
      )

      unless COMPLETED_PAYMENT_STATUSES.include?(stripe_session.payment_status)
        flash[:error] = "Payment was not completed successfully"
        return redirect_to cart_path
      end

      # Check if order already exists for this session (webhook may have created it)
      existing_order = Order.find_by(stripe_session_id: session_id)
      if existing_order
        return redirect_to confirmation_order_path(existing_order, token: existing_order.signed_access_token)
      end

      # Get the cart with eager loading for order creation
      cart = Current.cart
      if cart.blank? || cart.cart_items.empty?
        flash[:error] = "No items found in cart"
        return redirect_to root_path
      end

      order = Checkout::OrderCreator.new(stripe_session: stripe_session, cart: cart).create

      # Emit checkout.completed event
      Rails.event.notify("checkout.completed",
        order_id: order.id,
        total: order.total_amount.to_f,
        payment_method: stripe_session.payment_method_types&.first || "card"
      )

      # Emit order.placed event
      Rails.event.notify("order.placed",
        order_id: order.id,
        email: order.email,
        total: order.total_amount.to_f,
        item_count: order.order_items.count,
        has_discount: session[:discount_code].present?,
        source: "checkout"
      )

      # Clear the cart after successful order creation
      cart.cart_items.destroy_all

      # Send order confirmation email (customer + internal ops copy)
      OrderMailer.with(order: order).confirmation_email.deliver_later
      OrderMailer.with(order: order).ops_confirmation_email.deliver_later

      # Notify the team in Telegram that a new order has been placed
      TelegramOrderNotificationJob.perform_later(order.id)

      # Store in session for immediate access (proves ownership for guest checkout)
      session[:recent_order_id] = order.id

      # Emit discount claimed event if order used a discount code.
      # KlaviyoSubscriber resolves the customer email from order_id (Rails.event
      # filters payload[:email] to "[FILTERED]"), so order_id is the contract here.
      if session[:discount_code].present?
        Rails.event.notify("email_signup.discount_claimed",
          email: order.email,
          order_id: order.id,
          discount_code: session[:discount_code]
        )
      end

      # Clear discount code after successful order (one-time use)
      session.delete(:discount_code)

      # Redirect to confirmation page with signed token
      redirect_to confirmation_order_path(order, token: order.signed_access_token),
                  status: :see_other

    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error in checkout success: #{e.message}")
      Sentry.capture_exception(e, extra: { session_id: session_id })
      flash[:error] = "Unable to verify payment. Please contact support."
      redirect_to cart_path
    rescue Checkout::MissingShippingDetails => e
      Rails.logger.warn("Missing shipping details in checkout success: #{e.message}")
      Sentry.capture_exception(e, extra: { session_id: session_id })
      flash[:error] = "Shipping details are required. Please try checkout again."
      redirect_to cart_path
    end
  end

  def cancel
    redirect_to cart_path, notice: "Checkout cancelled."
  end
end
