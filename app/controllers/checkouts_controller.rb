class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: "Too many checkout attempts. Please wait before trying again." }
  # Looser than :create - a reprice fires once per completed address, but one
  # customer correcting typos can legitimately produce a burst.
  rate_limit to: 30, within: 1.minute, only: :update, with: -> { render json: { error: "Too many attempts. Please wait a moment." }, status: :too_many_requests }

  def create
    cart = Current.cart

    # Refuse to build a session for an empty cart. With no items the subtotal is 0,
    # which is below the free-shipping threshold, so a shipping line would still be
    # added - producing a shipping-only Checkout Session that could be charged.
    if cart.blank? || cart.cart_items.empty?
      return redirect_to cart_path, alert: "Your cart is empty."
    end

    # An UNKNOWN destination is allowed through: SessionBuilder prices it
    # mainland and the on-site page reprices from the address the customer
    # actually types (the hosted fallback accepts the mainland-default gap
    # rather than stranding customers who never met a postcode field). A
    # destination we KNOW we cannot serve is still refused - no reprice can fix
    # an order whose only address is somewhere we don't ship.
    if refused_destination?(params[:address_id])
      return redirect_to cart_path,
                         alert: ShippingZone.refusal_message(:undeliverable)
    end

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

      resolved_postcode = delivery_postcode_for(params[:address_id])

      builder = Checkout::SessionBuilder.new(
        cart: cart,
        user: Current.user,
        address_id: params[:address_id],
        discount_code: session[:discount_code],
        delivery_postcode: resolved_postcode,
        datafast_visitor_id: cookies[:datafast_visitor_id],
        datafast_session_id: cookies[:datafast_session_id],
        success_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancel_checkout_url,
        ui_mode: OnsiteCheckout.enabled?(session) ? :custom : :hosted,
        return_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}"
      )
      result = builder.create

      if result.invalid_discount?
        session.delete(:discount_code)
        flash[:alert] = "Your discount code could not be applied. Please continue with your order."
      end

      if result.selected_address_id.present?
        session[:selected_address_id] = result.selected_address_id
      else
        # A checkout with no selection (e.g. from the cart drawer, whose form
        # has no address selector) must not inherit one from an earlier
        # attempt: the on-site page would prefill and zone-guard an address
        # this checkout wasn't priced from.
        session.delete(:selected_address_id)
      end

      if OnsiteCheckout.enabled?(session)
        # Stash the custom-mode session for GET /checkout to render; only
        # members #show reads belong here (the stash is cookie payload on
        # every request). The fingerprint is computed AFTER the
        # invalid-discount cleanup above so both sides of the later staleness
        # comparison see the same (possibly cleared) discount code: otherwise
        # an invalid welcome code would false-bounce every render.
        session[:onsite_checkout] = {
          "client_secret" => result.session.client_secret,
          # The reprice endpoint updates whichever session this names and no
          # other: the client never sends a session id.
          "session_id" => result.session.id,
          "fingerprint" => Checkout::CartFingerprint.digest(
            cart: cart, postcode: resolved_postcode, discount_code: session[:discount_code]
          ),
          "zone" => result.zone.to_s,
          "created_at" => Time.current.to_i
        }
        redirect_to checkout_path, status: :see_other
      else
        redirect_to result.session.url, allow_other_host: true, status: :see_other
      end
    rescue Stripe::StripeError => e
      session.delete(:discount_code) if builder&.invalid_discount?
      Rails.logger.error("Stripe error: #{e.message}")
      flash[:error] = e.message
      redirect_to cart_path
    end
  end

  # Stripe expires Checkout Sessions 24 hours after creation; past that the
  # stashed client_secret can only produce a dead page whose "please refresh"
  # advice re-serves the same expired secret. Bounce just short of Stripe's
  # line so the customer lands on the cart with a working restart instead.
  ONSITE_STASH_TTL = 23.hours

  # The on-site checkout page. Renders the Stripe session stashed by #create;
  # performs no Stripe writes, so refresh and back-navigation are free.
  def show
    unless OnsiteCheckout.enabled?(session)
      # Flipping the flag off must not strand a stashed client_secret in the
      # cookie indefinitely.
      session.delete(:onsite_checkout)
      return redirect_to cart_path
    end

    stash = session[:onsite_checkout]
    cart = Current.cart
    return redirect_to cart_path if stash.blank? || cart.blank? || cart.cart_items.empty?

    if stash["created_at"].to_i < ONSITE_STASH_TTL.ago.to_i
      session.delete(:onsite_checkout)
      return redirect_to cart_path, notice: "Your checkout session expired. Continue to payment when you're ready."
    end

    # Re-resolve the destination exactly as #create did (typed postcode, then
    # the stashed address selection, then the default address). Falling back
    # to a postcode recorded in the stash instead would validate the stash
    # against itself: a postcode REMOVED from the session after #create went
    # unnoticed, and the page charged a destination the cart no longer shows.
    postcode = delivery_postcode_for(session[:selected_address_id])
    fingerprint = Checkout::CartFingerprint.digest(
      cart: cart, postcode: postcode, discount_code: session[:discount_code]
    )
    if fingerprint != stash["fingerprint"]
      session.delete(:onsite_checkout)
      return redirect_to cart_path, notice: "Your basket changed. Continue to payment when you're ready."
    end

    # The summary must price shipping from the destination the Stripe session
    # was built from. The before_action resolves the cart's postcode without
    # the address selection, so a saved-address checkout would otherwise
    # display a different shipping line than the session charges.
    cart.delivery_postcode = postcode

    @client_secret = stash["client_secret"]
    @priced_zone = stash["zone"]
    @show_promo = session[:discount_code].blank? && !cart.only_samples?
    @prefill_address = Current.user&.addresses&.find_by(id: session[:selected_address_id]) ||
                       Current.user&.addresses&.default_first&.first
    @customer_email = Current.user&.email_address
  end

  # Live shipping reprice for the on-site page: the customer completed (or
  # changed) their delivery address in the Stripe element, and under
  # permissions.update_shipping_details=server_only this endpoint is the ONLY
  # way that address - and the shipping price it implies - reaches the Stripe
  # session. JSON in, JSON out; the Stimulus controller resolves Stripe's
  # shipping-details callback from the response.
  #
  # Failure stance is fail-CLOSED on money: any refusal or error writes
  # nothing, so the stash keeps the zone the session actually charges and the
  # page's zone guard keeps Pay blocked on a mismatch. We can never fail open
  # into undercharging.
  def update
    stash = session[:onsite_checkout]
    cart = Current.cart

    unless OnsiteCheckout.enabled?(session) && stash.present? && stash["session_id"].present? &&
           cart.present? && cart.cart_items.any?
      return render json: { error: "This checkout is no longer active." }, status: :gone
    end

    if stash["created_at"].to_i < ONSITE_STASH_TTL.ago.to_i
      session.delete(:onsite_checkout)
      return render json: { error: "This checkout has expired." }, status: :gone
    end

    # The stash must still describe the cart as it stands, checked with the
    # DESTINATION THE SESSION WAS LAST PRICED FOR (resolved exactly as #show
    # does). Skipping this and recomputing the fingerprint from the changed
    # cart would overwrite the stash and mask exactly the staleness #show's
    # bounce exists to catch: the customer would pay the old total for a
    # basket the page no longer shows.
    priced_postcode = delivery_postcode_for(session[:selected_address_id])
    priced_fingerprint = Checkout::CartFingerprint.digest(
      cart: cart, postcode: priced_postcode, discount_code: session[:discount_code]
    )
    if priced_fingerprint != stash["fingerprint"]
      session.delete(:onsite_checkout)
      return render json: { error: "Your basket changed. Please return to it and check out again." },
                    status: :conflict
    end

    postcode = params[:postcode].to_s.strip

    begin
      result = Checkout::SessionRepricer.new(
        stripe_session_id: stash["session_id"],
        cart: cart,
        postcode: postcode,
        shipping_details: shipping_details_params(postcode),
        priced_zone: stash["zone"]
      ).call
    rescue Checkout::SessionRepricer::UndeliverableZone => e
      return render json: { error: ShippingZone.refusal_message(e.zone) }, status: :unprocessable_entity
    rescue Stripe::InvalidRequestError => e
      # The session completed or expired under us (e.g. Pay racing the reprice).
      Rails.logger.warn("Checkout reprice conflict: #{e.message}")
      return render json: { error: "This checkout can no longer be updated. Please refresh the page." },
                    status: :conflict
    rescue Stripe::StripeError => e
      Rails.logger.error("Checkout reprice failed: #{e.message}")
      return render json: { error: "We couldn't update delivery for that address. Please try again." },
                    status: :unprocessable_entity
    end

    # Coherence writes, only after Stripe accepted the update: the typed
    # postcode becomes the session postcode (delivery_postcode_for resolves the
    # typed value first, so #show's re-derived fingerprint matches the one
    # stored here), and the stash's zone follows the price now on the session.
    session[:delivery_postcode] = postcode
    session[:onsite_checkout] = stash.merge(
      "zone" => result.zone.to_s,
      "fingerprint" => Checkout::CartFingerprint.digest(
        cart: cart, postcode: postcode, discount_code: session[:discount_code]
      )
    )

    render json: {
      zone: result.zone.to_s,
      shipping_amount: formatted_shipping_amount(result.shipping_pence)
    }
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
        # total_details.breakdown is omitted unless expanded, and without it the
        # discount breakdown is nil, so the promotion code cannot be read and the
        # order records no discount_code.
        expand: [ "collected_information", "line_items.data.price.product",
                 "payment_intent.payment_method", "total_details.breakdown" ]
      )

      unless Checkout::COMPLETED_PAYMENT_STATUSES.include?(stripe_session.payment_status)
        flash[:error] = "Payment was not completed successfully"
        return redirect_to cart_path
      end

      # The stash's job ends with payment: without this the paid session's
      # client_secret would ride every later request's cookie.
      session.delete(:onsite_checkout)

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
        payment_method: Checkout::SessionDetails.payment_method_type(stripe_session)
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

    rescue ActiveRecord::RecordNotUnique => e
      # Lost the create race: the webhook committed the order for this session in the
      # window after our find_by check, so create! hit the unique stripe_session_id
      # index. Redirect to that order rather than 500 the paying customer. If no order
      # exists, the constraint fired for some other reason - a genuine inconsistency -
      # so surface it.
      existing_order = Order.find_by(stripe_session_id: session_id)
      raise e unless existing_order

      redirect_to confirmation_order_path(existing_order, token: existing_order.signed_access_token),
                  status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      # If the order exists, this is the model-level uniqueness validation firing
      # before the DB constraint - the same benign race as above, so redirect to it.
      existing_order = Order.find_by(stripe_session_id: session_id)
      if existing_order
        redirect_to confirmation_order_path(existing_order, token: existing_order.signed_access_token),
                    status: :see_other
      else
        # Otherwise a different validation rejected the order (e.g. an OrderItem
        # failed inside OrderCreator's transaction, rolling it back). The customer
        # has already paid, so never 422 them: capture for investigation and redirect
        # gracefully. The webhook fallback still creates the order.
        Rails.logger.error("Order validation failed in checkout success: #{e.message}")
        Sentry.capture_exception(e, extra: { session_id: session_id })
        flash[:error] = "Unable to verify payment. Please contact support."
        redirect_to cart_path
      end
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
    rescue Checkout::SessionAmounts::UnexpandedLineItemError => e
      # Programmer error (a dropped expand): don't 500 the paid customer. The
      # webhook fallback still creates the order; surface for investigation.
      Rails.logger.error("Unexpanded line item in checkout success: #{e.message}")
      Sentry.capture_exception(e, extra: { session_id: session_id })
      flash[:error] = "Unable to verify payment. Please contact support."
      redirect_to cart_path
    end
  end

  def cancel
    redirect_to cart_path, notice: "Checkout cancelled."
  end

  private

  # The postcode used to price delivery.
  #
  # This MUST resolve in the same order as the cart preview
  # (ApplicationController#apply_session_delivery_postcode_to_cart), because the
  # price the cart quoted is the price we promised. The typed field therefore
  # wins over a selected saved address, and the customer's default address is
  # the last resort. The two once disagreed in opposite directions and produced
  # two bugs: typing a mainland postcode then selecting a saved Highlands
  # address quoted £6.99 and charged £25, and a customer whose cart priced from
  # their default address was refused at checkout for not selecting one.
  #
  # The selected address is still consulted, so a logged-in customer who picked a
  # saved address without typing anything is priced from it rather than refused.
  # Nil means mainland pricing, as today.
  def delivery_postcode_for(address_id)
    session[:delivery_postcode].presence ||
      selected_address_postcode(address_id) ||
      default_address_postcode
  end

  # Whether the destination we WOULD price from is one we know we cannot serve.
  # Only :undeliverable refuses; :unknown (no postcode anywhere, or an
  # unparseable one) proceeds priced as mainland - see the comment at the call
  # site in #create.
  def refused_destination?(address_id)
    ShippingZone.for(delivery_postcode_for(address_id)) == :undeliverable
  end

  # The shipping details recorded on the Stripe session, pass-through from what
  # the address element collected. The typed postcode rides in its canonical
  # slot; the rest is display data Stripe echoes back on the completed session.
  def shipping_details_params(postcode)
    permitted = params.permit(:name, :line1, :line2, :city, :country)
    {
      name: permitted[:name],
      address: {
        line1: permitted[:line1],
        line2: permitted[:line2],
        city: permitted[:city],
        postal_code: postcode,
        country: permitted[:country].presence || "GB"
      }
    }
  end

  # "Free" or the currency amount, matching CartSummary's shipping line so the
  # page's repriced shipping row reads exactly like the server-rendered one.
  def formatted_shipping_amount(pence)
    return "Free" if pence.zero?

    ActiveSupport::NumberHelper.number_to_currency(pence / 100.0, unit: "£")
  end

  def selected_address_postcode(address_id)
    return nil if address_id.blank? || Current.user.blank?

    Current.user.addresses.find_by(id: address_id)&.postcode
  end
end
