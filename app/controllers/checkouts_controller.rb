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
    if refused_destination?
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

      resolved_postcode = delivery_postcode_for

      builder = Checkout::SessionBuilder.new(
        cart: cart,
        user: Current.user,
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
        # A below-minimum discount is a nudge, not a fault: an error bar
        # misreads "spend £54 more" as something having gone wrong, so it gets
        # the dedicated :nudge slot. Everything else genuinely is a refusal.
        if result.discount_refusal_reason == :below_minimum
          flash[:nudge] = discount_refusal_message(result, cart)
        else
          flash[:alert] = discount_refusal_message(result, cart)
        end
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
          # What the session's frozen shipping line charges, so the same-zone
          # reprice short-circuit can quote it without recomputing from live
          # constants (which a deploy could have changed mid-checkout).
          "shipping_pence" => Checkout::SessionRepricer.shipping_pence(zone: result.zone, cart: cart),
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

  # The on-site checkout page. Renders the Stripe session stashed by #create;
  # performs no Stripe writes, so refresh and back-navigation are free.
  def show
    unless OnsiteCheckout.enabled?(session)
      # Flipping the flag off must not strand a stashed client_secret in the
      # cookie indefinitely.
      session.delete(:onsite_checkout)
      return redirect_to cart_path
    end

    cart = Current.cart
    # Re-resolve the destination exactly as #create did (typed postcode, then
    # the default address); StashedSession validates the stash against it
    # rather than against a postcode of its own. A destination that CHANGED
    # after #create (a default address edited in another tab) means the page
    # would charge a destination it no longer shows.
    postcode = delivery_postcode_for
    verdict = Checkout::StashedSession.revalidate(
      session: session, cart: cart, postcode: postcode, discount_code: session[:discount_code]
    )
    case verdict.state
    when :absent
      return redirect_to cart_path
    when :expired
      return redirect_to cart_path, notice: "Your checkout session expired. Continue to payment when you're ready."
    when :stale
      return redirect_to cart_path, notice: "Your basket changed. Continue to payment when you're ready."
    end
    stash = verdict.stash

    # The summary must price shipping from the destination the Stripe session
    # was built from. The before_action resolves the cart's postcode without
    # the address selection, so a saved-address checkout would otherwise
    # display a different shipping line than the session charges. With no
    # destination at all the session still charges a concrete zone
    # (SessionBuilder's mainland fallback), so the summary prices that instead
    # of deferring: a deferred shipping line beside the SDK-painted total
    # (which includes shipping) would not add up.
    cart.delivery_postcode = postcode
    cart.price_unknown_destination = true

    @client_secret = stash["client_secret"]
    @priced_zone = stash["zone"]
    @show_promo = session[:discount_code].blank? && !cart.only_samples?
    @prefill_address = prefill_address_for(postcode)
    @customer_email = Current.user&.email_address
  end

  # Live shipping reprice for the on-site page: the customer completed (or
  # changed) their delivery address in the Stripe element, and this endpoint
  # re-prices the open session's shipping line for the typed postcode's zone.
  # The address itself syncs to Stripe client-side (as on the hosted page);
  # the server owns only the price. JSON in, JSON out; the Stimulus controller
  # calls this inside the SDK's runServerUpdate so totals refresh after.
  #
  # Failure stance is fail-CLOSED on money: any refusal or error writes
  # nothing, so the stash keeps the zone the session actually charges and the
  # page's zone guard keeps Pay blocked on a mismatch. We can never fail open
  # into undercharging.
  def update
    cart = Current.cart

    unless OnsiteCheckout.enabled?(session)
      return render json: { error: "This checkout is no longer active." }, status: :gone
    end

    # The stash must still describe the cart as it stands, checked with the
    # DESTINATION THE SESSION WAS LAST PRICED FOR (resolved exactly as #show
    # does, in the shared StashedSession rules). Recomputing the fingerprint
    # from the changed cart instead would overwrite the stash and mask exactly
    # the staleness #show's bounce exists to catch: the customer would pay the
    # old total for a basket the page no longer shows.
    priced_postcode = delivery_postcode_for
    verdict = Checkout::StashedSession.revalidate(
      session: session, cart: cart, postcode: priced_postcode, discount_code: session[:discount_code]
    )
    case verdict.state
    when :absent
      return render json: { error: "This checkout is no longer active." }, status: :gone
    when :expired
      return render json: { error: "This checkout has expired." }, status: :gone
    when :stale
      return render json: { error: "Your basket changed. Please return to it and check out again." },
                    status: :conflict
    end
    stash = verdict.stash

    # The stash names the only Stripe session this endpoint may update, but it
    # is shared by every checkout tab in the browser, and each POST /checkout
    # rewrites it: an OLDER tab's reprice would otherwise update the NEWER
    # tab's session while its own page keeps displaying (and could pay) the
    # session it actually holds. The tab proves it is the stashed one with its
    # client_secret; a mismatch refuses the write and KEEPS the stash, which
    # belongs to the newer, healthy tab. (live-observed 2026-08-18)
    unless ActiveSupport::SecurityUtils.secure_compare(
      params[:client_secret].to_s, stash["client_secret"].to_s
    )
      return render json: { error: "This checkout was reopened in another tab or window. Please return to your basket." },
                    status: :conflict
    end

    postcode = params[:postcode].to_s.strip
    zone = ShippingZone.for(postcode)
    unless ShippingZone.deliverable?(zone)
      return render json: { error: ShippingZone.refusal_message(zone) }, status: :unprocessable_entity
    end

    # Same zone ⇒ the session's shipping line is already right and Stripe
    # needs no call at all; only the session-side records move (a different
    # postcode within the zone still changes the fingerprint). This is also
    # what makes the on-mount reprice of a prefilled address free.
    shipping_pence = nil
    if zone.to_s != stash["zone"]
      begin
        shipping_pence = Checkout::SessionRepricer.new(
          stripe_session_id: stash["session_id"], cart: cart, postcode: postcode
        ).call.shipping_pence
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
    end

    # The short-circuit branch never priced anything: quote the amount frozen
    # in the stash, not today's constants - a shipping-price deploy
    # mid-checkout would otherwise display a price the session's frozen line
    # item does not charge. Stashes written before the key existed fall back
    # to the live quote (correct until their 23h TTL passes the deploy).
    shipping_pence ||= stash["shipping_pence"] || Checkout::SessionRepricer.shipping_pence(zone: zone, cart: cart)

    # Coherence writes, only after Stripe accepted (or needed no) update: the
    # typed postcode becomes the session postcode (delivery_postcode_for
    # resolves the typed value first, so #show's re-derived fingerprint matches
    # the one stored here), and the stash's zone and shipping follow the
    # session's price. The fingerprint reuses the validator's loaded items.
    session[:delivery_postcode] = postcode
    session[:onsite_checkout] = stash.merge(
      "zone" => zone.to_s,
      "shipping_pence" => shipping_pence,
      "fingerprint" => Checkout::CartFingerprint.digest(
        cart: cart, postcode: postcode, discount_code: session[:discount_code], items: verdict.items
      )
    )

    render json: {
      zone: zone.to_s,
      shipping_amount: CartSummary.format_shipping(shipping_pence / 100.0)
    }
  end

  # The success redirect completion channel (see CONTEXT.md: Checkout
  # completion). Checkout::Completion owns what a completion does and reports
  # its own failures; this action owns only the transport: the flash and
  # redirect for each outcome, and the browser-session cleanup.
  def success
    session_id = params[:session_id]

    unless session_id.present?
      flash[:error] = "Invalid checkout session"
      return redirect_to cart_path
    end

    outcome = Checkout::Completion.complete(session_id, browser_present: true)

    if outcome.unpaid?
      # The stash survives so the customer can retry on the on-site page.
      flash[:error] = "Payment was not completed successfully"
      return redirect_to cart_path
    end

    # The stash's job ends with payment: without this the paid session's
    # client_secret would ride every later request's cookie.
    session.delete(:onsite_checkout)

    if outcome.created?
      # Proves ownership of the fresh order for guest checkout, and the Welcome
      # discount is one-time: the metadata on the session already decided
      # whether it was applied, so the browser copy is simply spent.
      session[:recent_order_id] = outcome.order.id
      session.delete(:discount_code)
    end

    redirect_to confirmation_order_path(outcome.order, token: outcome.order.signed_access_token),
                status: :see_other
  rescue Checkout::MissingShippingDetails
    flash[:error] = "Shipping details are required. Please try checkout again."
    redirect_to cart_path
  rescue Checkout::PermanentCompletionFailure, Checkout::TransientCompletionFailure
    # The customer has already paid, so never 500 or 422 them. Completion has
    # captured the failure; the webhook channel still completes the order.
    flash[:error] = "Unable to verify payment. Please contact support."
    redirect_to cart_path
  end

  def cancel
    redirect_to cart_path, notice: "Checkout cancelled."
  end

  private

  # What to tell a customer whose discount was dropped.
  #
  # The old blanket "could not be applied" stated a failure and gave them nothing
  # to act on. Each refusal has a different remedy (or none), and the
  # below-minimum case in particular is worth spelling out: naming the shortfall
  # turns an apology into a reason to add to the order, which is what the £100
  # floor exists for.
  #
  # An unrecognised reason falls back to the old wording rather than raising: a
  # customer mid-checkout should never be blocked by a missing string.
  def discount_refusal_message(result, cart)
    case result.discount_refusal_reason
    when :below_minimum
      shortfall = helpers.welcome_discount_shortfall(cart)
      minimum = helpers.welcome_discount_minimum
      percentage = helpers.welcome_discount_percentage

      if shortfall.positive?
        "Your #{percentage}% discount needs an order of #{minimum} or more. " \
          "Add #{helpers.number_to_currency(shortfall, unit: "£")} to your order to use it."
      else
        "Your #{percentage}% discount needs an order of #{minimum} or more, before delivery."
      end
    when :samples_only
      "Samples are already free, so the discount does not apply to a samples-only order."
    when :not_first_order
      "Your #{helpers.welcome_discount_percentage}% discount is for first orders only."
    else
      "Your discount code could not be applied. Please continue with your order."
    end
  end

  # The cart the paid session was built from, named in its metadata (the same
  # key the webhook fallback reads), NOT whichever cart this browser happens to
  # hold. An agent-created checkout has no browser cart behind it, so falling
  # back to Current.cart would turn unrelated items into the order and clear
  # them. Sessions predating the metadata key still resolve to the browser cart.
  # The postcode used to price delivery: the one typed at the checkout page
  # (PATCH /checkout is its only writer, and it survives that Stripe session),
  # falling back to the customer's default address. Nil means mainland pricing.
  # #create, #show and #update must all resolve through this so the priced
  # session, the rendered summary and the reprice pre-check can never disagree
  # about where the order is going.
  def delivery_postcode_for
    session[:delivery_postcode].presence || default_address_postcode
  end

  # Whether the destination we WOULD price from is one we know we cannot serve.
  # Only :undeliverable refuses; :unknown (no postcode anywhere, or an
  # unparseable one) proceeds priced as mainland - see the comment at the call
  # site in #create.
  def refused_destination?
    ShippingZone.for(delivery_postcode_for) == :undeliverable
  end

  # The saved address mounted into the Stripe element - but only when it
  # matches the postcode the session is priced from. A completed prefill fires
  # the on-mount reprice, so mounting an address with a DIFFERENT postcode
  # (typed postcodes outrank the default address in delivery_postcode_for)
  # would auto-reprice and silently overwrite the postcode the customer typed,
  # and visibly move the total while they touched nothing. The element starts
  # blank instead; Stripe's own "Use a saved address" (from the attached
  # Customer) makes picking one an explicit choice.
  def prefill_address_for(priced_postcode)
    address = Current.user&.addresses&.default_first&.first
    return address if address.nil? || priced_postcode.nil?

    address if ShippingZone.normalise(address.postcode) == ShippingZone.normalise(priced_postcode)
  end
end
