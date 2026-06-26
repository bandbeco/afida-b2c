module Checkout
  class OrderCreator
    def initialize(stripe_session:, cart:)
      @stripe_session = stripe_session
      @cart = cart
    end

    def create
      shipping_address = Checkout::SessionDetails.shipping_address(stripe_session)
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
      # An unexpected Stripe discount shape is allowed to surface here so a
      # success-path failure is visible (the webhook fallback still creates the
      # order); the webhook rescues the same call to nil instead.
      stripe_session.metadata&.[]("discount_code").presence ||
        Checkout::SessionDetails.promotion_code(stripe_session)
    end
  end
end
