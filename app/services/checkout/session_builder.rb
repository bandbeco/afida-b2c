module Checkout
  class SessionBuilder
    Result = Struct.new(:session, :invalid_discount_code, :selected_address_id, :zone, keyword_init: true) do
      def invalid_discount?
        invalid_discount_code.present?
      end
    end

    def initialize(cart:, user:, address_id:, discount_code:, datafast_visitor_id:, datafast_session_id:, success_url:, cancel_url:, delivery_postcode: nil, ui_mode: :hosted, return_url: nil)
      @cart = cart
      @user = user
      @address_id = address_id
      @discount_code = discount_code
      @delivery_postcode = delivery_postcode
      @datafast_visitor_id = datafast_visitor_id
      @datafast_session_id = datafast_session_id
      @success_url = success_url
      @cancel_url = cancel_url
      @ui_mode = ui_mode
      @return_url = return_url
    end

    # Mirrors Result#invalid_discount? so the controller can clean up session
    # state even when Stripe::Checkout::Session.create raises after validation.
    def invalid_discount?
      invalid_discount_code.present?
    end

    def create
      session_params = build_session_params
      @invalid_discount_code = apply_discount(session_params)
      @selected_address_id = apply_customer_details(session_params)

      Result.new(
        session: Stripe::Checkout::Session.create(session_params),
        invalid_discount_code: invalid_discount_code,
        selected_address_id: selected_address_id,
        zone: zone
      )
    end

    private

    attr_reader :cart, :user, :address_id, :discount_code, :delivery_postcode, :datafast_visitor_id,
                :datafast_session_id, :success_url, :cancel_url, :invalid_discount_code, :selected_address_id,
                :ui_mode, :return_url

    def build_session_params
      {
        line_items: line_items,
        mode: "payment",
        shipping_address_collection: {
          allowed_countries: Shipping::ALLOWED_COUNTRIES
        },
        metadata: {
          cart_id: cart.id.to_s,
          discount_code: discount_code,
          datafast_visitor_id: datafast_visitor_id,
          datafast_session_id: datafast_session_id,
          # The zone the order was PRICED against, which is not necessarily the
          # zone of the address Stripe collects on the next screen. The order
          # records what the customer was actually charged, so it reads this back
          # rather than re-deriving from the delivered-to postcode.
          shipping_zone: zone.to_s
        }
      }.merge(mode_params)
    end

    # The ONLY params allowed to differ between hosted and custom mode. The
    # custom (on-site) page shows wallets and Link inside the Payment Element;
    # hosted stays card-only exactly as it always was.
    def mode_params
      if ui_mode == :custom
        {
          ui_mode: "custom",
          return_url: return_url,
          payment_method_types: [ "card", "link" ]
        }
      else
        {
          payment_method_types: [ "card" ],
          success_url: success_url,
          cancel_url: cancel_url
        }
      end
    end

    # Product line items plus, unless shipping is free, the taxed shipping line.
    # Shipping rides as a line item (not a shipping_option) so that under manual
    # tax rates Stripe applies VAT to the delivery charge too.
    #
    # The shipping line is prepended as a best-effort optimisation: Stripe's
    # retrieve returns only the first 10 line_items (and does not promise an
    # order), so keeping shipping early makes it likely to land on the embedded
    # page and spare SessionAmounts an extra pagination call. Correctness does
    # not depend on it - SessionAmounts pages through all line items when needed.
    def line_items
      items = product_line_items
      items.unshift(shipping_line_item) if shipping_line_item
      items
    end

    def product_line_items
      cart.cart_items.includes(Checkout::CART_ITEM_INCLUDES).map do |item|
        {
          quantity: stripe_quantity(item),
          price_data: {
            currency: "gbp",
            product_data: {
              name: product_name(item)
            },
            unit_amount: unit_amount(item),
            tax_behavior: "exclusive"
          },
          tax_rates: [ tax_rate.id ]
        }
      end
    end

    def stripe_quantity(item)
      return 1 if item.sample? || item.configured?
      return item.quantity if unit_priced?(item)

      # Pack-priced items fold pack count into unit_amount for one Stripe subtotal.
      1
    end

    def unit_amount(item)
      if item.sample?
        0
      elsif item.configured?
        (item.price.to_f * item.quantity * 100).round
      elsif unit_priced?(item)
        (item.price.to_f * 100).round
      else
        # Pack-priced items use one Stripe line item with the pack count folded
        # into unit_amount, so Stripe's tax/discount math sees one subtotal.
        (item.price.to_f * item.quantity * 100).round
      end
    end

    def product_name(item)
      product = item.product

      if item.sample?
        "#{product.generated_title} (Sample)"
      elsif item.configured?
        units_formatted = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
        "#{product.generated_title} - #{item.configuration['size']} (#{units_formatted} units)"
      elsif unit_priced?(item)
        product.generated_title
      else
        packs_label = item.quantity == 1 ? "pack" : "packs"
        "#{product.generated_title} (#{item.quantity} #{packs_label})"
      end
    end

    def unit_priced?(item)
      item.product.pac_size.blank? || item.product.pac_size.zero?
    end

    # The taxed shipping line item, or nil when the order ships free. Keyed off the
    # subtotal vs the free-shipping threshold and the destination zone, the same
    # rule OrderTotals uses for the displayed totals - keep the two in step.
    # Samples-only carts have a £0 subtotal (samples are free), which is below the
    # threshold, so they correctly still pay shipping.
    #
    # Free delivery is a mainland promise, so a large order to a surcharged zone
    # still gets a shipping line. This is the fix for orders that shipped free to
    # Northern Ireland and the Highlands.
    def shipping_line_item
      return @shipping_line_item if defined?(@shipping_line_item)

      free = ShippingZone.free_shipping?(zone) && cart.subtotal_amount >= Shipping::FREE_SHIPPING_THRESHOLD

      @shipping_line_item =
        unless free
          Shipping.shipping_line_item(tax_rate_id: tax_rate.id, zone: zone)
        end
    end

    # The destination zone, from the postcode captured on the cart page. Stripe
    # only collects the real address on the next screen, but line-item prices are
    # fixed here, so the price has to be based on what the customer told us.
    #
    # An absent or unparseable postcode falls back to mainland. That under-prices
    # a non-mainland order, but the alternative is blocking a paying customer over
    # a field they were never required to fill in. The order still records the
    # real address Stripe collects, so a mismatch is visible after the fact.
    def zone
      @zone ||= begin
        resolved = ShippingZone.for(delivery_postcode)
        ShippingZone.deliverable?(resolved) ? resolved : :mainland
      end
    end

    def apply_discount(session_params)
      # Samples are free, so a samples-only order pays only shipping. Refuse all
      # discounts (both a supplied code and Stripe-entered promo codes) so a coupon
      # can never reduce or zero that shipping charge. A supplied code is reported
      # as not applied via the return value, mirroring the invalid-coupon path.
      if cart.only_samples?
        session_params[:metadata].delete(:discount_code)
        return discount_code.presence
      end

      # The welcome coupon is injected into the session at signup and can sit in the
      # cookie for its full lifetime, so eligibility is re-checked when it is actually
      # spent rather than only when it was granted. Only a customer we can identify is
      # checked here; a guest's email is unknown until Stripe collects it, so Stripe's
      # own first_time_transaction restriction enforces that case.
      if discount_code.present? && !welcome_discount_allowed?
        session_params[:metadata].delete(:discount_code)
        # Refusing THIS coupon must not withdraw the promo-code field itself: the
        # switch governs every code, so a repeat customer denied the welcome coupon
        # must still be able to type a current campaign code.
        session_params[:allow_promotion_codes] = true
        return discount_code.presence
      end

      if discount_code.present?
        apply_session_discount(session_params)
      else
        # Left on for everyone: this switch governs EVERY promotion code, not just the
        # welcome one, so gating it on welcome-coupon eligibility would silently
        # withdraw future campaign codes from repeat customers. Per-coupon limits are
        # Stripe's job (first_time_transaction on the welcome code).
        session_params[:allow_promotion_codes] = true
        nil
      end
    end

    # Whether the session-carried welcome coupon may still be spent.
    #
    # Deliberately NOT EmailSubscription.eligible_for_discount?: that rule also refuses
    # an email whose discount_claimed_at is set, which is exactly the state of every
    # customer arriving here legitimately (the signup form stamps it when the coupon is
    # GRANTED, always before the order that spends it). Only a completed ORDER means
    # this is no longer a first order.
    #
    # Only COMPLETED orders count: a pending order never paid, and a cancelled or
    # refunded one was reversed, so counting either would permanently burn a
    # legitimately claimed discount for someone whose first attempt fell through.
    #
    # Orders are matched by ACCOUNT as well as by email: a customer can check out as a
    # guest under a different address than they registered with, so neither signal
    # alone is enough. Unknown (guest) customers pass here and are caught by Stripe's
    # first_time_transaction restriction instead.
    def welcome_discount_allowed?
      return true unless user

      scope = Order.where(status: Order::COMPLETED_STATUSES)
      !scope.where(user_id: user.id).or(scope.where(email: user.email_address)).exists?
    end

    # The session carries the Stripe coupon id (the single source of truth in
    # credentials). Resolve it to the coupon's customer-facing promotion code, apply
    # that promotion code, and rewrite the metadata to the promotion code's name so
    # the order records the recognizable code (e.g. "WELCOME10") rather than the
    # opaque coupon id. Stripe is the only source of the name, so nothing is
    # hardcoded. A coupon with no active promotion code falls back to applying the
    # coupon by id directly (and records the id, since there is no friendlier name).
    def apply_session_discount(session_params)
      promotion_code = Stripe::PromotionCode.list(coupon: discount_code, active: true, limit: 1).data.first
      if promotion_code
        session_params[:discounts] = [ { promotion_code: promotion_code.id } ]
        session_params[:metadata][:discount_code] = promotion_code.code
        return nil
      end

      Stripe::Coupon.retrieve(discount_code)
      session_params[:discounts] = [ { coupon: discount_code } ]
      nil
    rescue Stripe::InvalidRequestError => e
      Rails.logger.warn("Invalid discount coupon '#{discount_code}': #{e.message}")
      # Do not persist unusable customer input to Stripe metadata.
      session_params[:metadata].delete(:discount_code)
      session_params[:allow_promotion_codes] = true
      discount_code
    end

    # Every session must end up tied to a Stripe Customer, because Stripe's coupon
    # restrictions (first_time_transaction, max_redemptions_per_customer) are keyed to
    # one. Sessions that carried only customer_email, or nothing at all, created no
    # Customer, so every checkout looked like a first-time party and a one-time coupon
    # could be redeemed indefinitely. A known user reuses their Customer; a guest gets
    # customer_creation: "always" so Stripe persists one from the email it collects.
    def apply_customer_details(session_params)
      unless user
        session_params[:customer_creation] = "always"
        return nil
      end

      session_params[:client_reference_id] = user.id

      if address_id.present?
        apply_selected_address(session_params)
      else
        # Deliberately NOT attaching the Stripe Customer here. Passing `customer` makes
        # Stripe prefill that customer's saved address, and reaching this branch means
        # they chose to enter a different address (or never selected one), so
        # prefilling would override that choice. customer_email keeps the address page
        # blank while customer_creation still has Stripe persist a Customer, which is
        # the part coupon restrictions key on.
        session_params[:customer_email] = user.email_address
        session_params[:customer_creation] = "always"
        nil
      end
    end

    def apply_selected_address(session_params)
      address = user.addresses.find_by(id: address_id)
      unless address
        session_params[:customer_email] = user.email_address
        session_params[:customer_creation] = "always"
        return nil
      end

      user.sync_stripe_customer!(address: address)
      session_params[:customer] = user.stripe_customer_id
      address_id
    end

    def tax_rate
      @tax_rate ||= StripeTaxRateProvider.new.tax_rate
    end
  end
end
