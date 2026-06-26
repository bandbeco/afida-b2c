module Checkout
  class OrderCreator
    def initialize(stripe_session:, cart:)
      @stripe_session = stripe_session
      @cart = cart
    end

    def create
      shipping_address = extract_shipping_address
      if Order.required_shipping_values(shipping_address).any?(&:blank?)
        raise Checkout::MissingShippingDetails, "Shipping details are required"
      end

      ApplicationRecord.transaction do
        order = Order.create!(order_attributes(shipping_address))

        cart_items.each do |cart_item|
          OrderItem.build_from_cart_item(cart_item, order).save!
        end

        order
      end
    end

    private

    attr_reader :stripe_session, :cart

    def order_attributes(shipping_address)
      amounts = Checkout::SessionAmounts.from(stripe_session)
      attributes = {
        user: user,
        organization: user&.organization,
        placed_by_user: user&.organization_id? ? user : nil,
        email: stripe_session.customer_details.email,
        stripe_session_id: stripe_session.id,
        status: "paid",
        subtotal_amount: amounts.subtotal,
        vat_amount: amounts.vat,
        shipping_amount: amounts.shipping,
        total_amount: amounts.total,
        discount_amount: amounts.discount,
        discount_code: discount_code.presence,
        shipping_name: shipping_address[:name],
        shipping_address_line1: shipping_address[:line1],
        shipping_address_line2: shipping_address[:line2],
        shipping_city: shipping_address[:city],
        shipping_postal_code: shipping_address[:postal_code],
        shipping_country: shipping_address[:country]
      }

      attributes[:branded_order_status] = "design_pending" if cart_items.any?(&:configured?)
      attributes
    end

    def cart_items
      @cart_items ||= cart.cart_items.includes(Checkout::CART_ITEM_INCLUDES).load
    end

    def user
      return @user if defined?(@user)

      @user = User.find_by(id: stripe_session.client_reference_id)
    end

    def discount_code
      stripe_session.metadata&.[]("discount_code").presence || extract_promotion_code
    end

    def extract_shipping_address
      session_hash = stripe_session.to_hash.with_indifferent_access

      shipping = session_hash.dig(:collected_information, :shipping_details)
      return {} unless shipping

      shipping = shipping.with_indifferent_access if shipping.respond_to?(:with_indifferent_access)
      address = shipping[:address]
      return {} unless address

      address = address.with_indifferent_access if address.respond_to?(:with_indifferent_access)

      {
        name: shipping[:name],
        line1: address[:line1],
        line2: address[:line2],
        city: address[:city],
        postal_code: address[:postal_code],
        country: address[:country]
      }
    end

    def extract_promotion_code
      # Stripe discount objects should follow this shape. Unexpected method
      # errors are allowed to surface so checkout success failures are visible.
      stripe_session
        .total_details
        &.breakdown
        &.discounts
        &.first
        &.discount
        &.promotion_code
        &.code
    end
  end
end
