module Checkout
  class SessionBuilder
    Result = Struct.new(:session, :invalid_discount_code, :selected_address_id, keyword_init: true) do
      def invalid_discount?
        invalid_discount_code.present?
      end
    end

    def initialize(cart:, user:, address_id:, discount_code:, datafast_visitor_id:, datafast_session_id:, success_url:, cancel_url:)
      @cart = cart
      @user = user
      @address_id = address_id
      @discount_code = discount_code
      @datafast_visitor_id = datafast_visitor_id
      @datafast_session_id = datafast_session_id
      @success_url = success_url
      @cancel_url = cancel_url
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
        selected_address_id: selected_address_id
      )
    end

    private

    attr_reader :cart, :user, :address_id, :discount_code, :datafast_visitor_id, :datafast_session_id, :success_url,
                :cancel_url, :invalid_discount_code, :selected_address_id

    def build_session_params
      {
        payment_method_types: [ "card" ],
        line_items: line_items,
        mode: "payment",
        shipping_address_collection: {
          allowed_countries: Shipping::ALLOWED_COUNTRIES
        },
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: {
          cart_id: cart.id.to_s,
          discount_code: discount_code,
          datafast_visitor_id: datafast_visitor_id,
          datafast_session_id: datafast_session_id
        }
      }
    end

    # Product line items plus, unless shipping is free, the taxed shipping line.
    # Shipping rides as a line item (not a shipping_option) so that under manual
    # tax rates Stripe applies VAT to the delivery charge too.
    #
    # The shipping line is prepended, not appended: Stripe::Checkout::Session
    # .retrieve returns only the first 10 line_items by default, so for a cart
    # with 10+ products an appended shipping line would fall off page 1 and
    # SessionAmounts would record shipping as £0 with an inflated subtotal. As
    # the first item it is always on page 1.
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
    # subtotal vs the free-shipping threshold, the same rule OrderTotals uses for
    # the displayed totals. Samples-only carts have a £0 subtotal (samples are
    # free), which is below the threshold, so they correctly still pay shipping.
    def shipping_line_item
      return @shipping_line_item if defined?(@shipping_line_item)

      @shipping_line_item =
        if cart.subtotal_amount < Shipping::FREE_SHIPPING_THRESHOLD
          Shipping.shipping_line_item(tax_rate_id: tax_rate.id)
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

      if discount_code.present?
        apply_session_discount(session_params)
      else
        session_params[:allow_promotion_codes] = true
        nil
      end
    end

    def apply_session_discount(session_params)
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

    def apply_customer_details(session_params)
      return nil unless user

      session_params[:client_reference_id] = user.id

      if address_id.present?
        apply_selected_address(session_params)
      else
        session_params[:customer_email] = user.email_address
        nil
      end
    end

    def apply_selected_address(session_params)
      address = user.addresses.find_by(id: address_id)
      unless address
        session_params[:customer_email] = user.email_address
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
