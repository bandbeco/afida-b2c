module Checkout
  class OrderCreator
    def initialize(stripe_session:, cart:)
      @stripe_session = stripe_session
      @cart = cart
    end

    def create
      order = Order.create!(order_attributes)

      if cart.cart_items.any?(&:configured?)
        order.update!(branded_order_status: "design_pending")
      end

      cart.cart_items.each do |cart_item|
        OrderItem.create_from_cart_item(cart_item, order).save!
      end

      order
    end

    private

    attr_reader :stripe_session, :cart

    def order_attributes
      user = User.find_by(id: stripe_session.client_reference_id)
      shipping_address = extract_shipping_address

      if required_shipping_values(shipping_address).any?(&:blank?)
        raise "Shipping details are required"
      end

      {
        user: user,
        organization: user&.organization,
        placed_by_user: user&.organization_id? ? user : nil,
        email: stripe_session.customer_details.email,
        stripe_session_id: stripe_session.id,
        status: "paid",
        subtotal_amount: stripe_session.amount_subtotal / 100.0,
        vat_amount: (stripe_session.total_details&.amount_tax || 0) / 100.0,
        shipping_amount: (stripe_session.shipping_cost&.amount_total || 0) / 100.0,
        total_amount: stripe_session.amount_total / 100.0,
        discount_amount: (stripe_session.total_details&.amount_discount || 0) / 100.0,
        discount_code: discount_code.presence,
        shipping_name: shipping_address[:name],
        shipping_address_line1: shipping_address[:line1],
        shipping_address_line2: shipping_address[:line2],
        shipping_city: shipping_address[:city],
        shipping_postal_code: shipping_address[:postal_code],
        shipping_country: shipping_address[:country]
      }
    end

    def required_shipping_values(shipping_address)
      [
        shipping_address[:name],
        shipping_address[:line1],
        shipping_address[:city],
        shipping_address[:postal_code],
        shipping_address[:country]
      ]
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
      stripe_session
        .total_details
        &.breakdown
        &.discounts
        &.first
        &.discount
        &.promotion_code
        &.code
    rescue NoMethodError
      nil
    end
  end
end
