module Checkout
  class SessionBuilder
    CART_ITEM_INCLUDES = [ :product, { design_attachment: :blob } ].freeze

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

    attr_reader :invalid_discount_code, :selected_address_id

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

    attr_reader :cart, :user, :address_id, :discount_code, :datafast_visitor_id, :datafast_session_id, :success_url, :cancel_url

    def build_session_params
      {
        payment_method_types: [ "card" ],
        line_items: line_items,
        mode: "payment",
        shipping_address_collection: {
          allowed_countries: Shipping::ALLOWED_COUNTRIES
        },
        shipping_options: shipping_options,
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

    def line_items
      cart.cart_items.includes(CART_ITEM_INCLUDES).map do |item|
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
      return item.quantity if item.product.pac_size.blank? || item.product.pac_size.zero?

      1
    end

    def unit_amount(item)
      if item.sample?
        0
      elsif item.configured?
        (item.price.to_f * item.quantity * 100).round
      elsif item.product.pac_size.blank? || item.product.pac_size.zero?
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
      elsif product.pac_size.blank? || product.pac_size.zero?
        product.generated_title
      else
        packs_label = item.quantity == 1 ? "pack" : "packs"
        "#{product.generated_title} (#{item.quantity} #{packs_label})"
      end
    end

    def shipping_options
      if cart.only_samples?
        [ Shipping.sample_only_shipping_option ]
      else
        Shipping.shipping_options_for_subtotal(cart.subtotal_amount)
      end
    end

    def apply_discount(session_params)
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
      session_params[:metadata][:discount_code] = nil
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
