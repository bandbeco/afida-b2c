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
        order = Order.create!(order_attributes)

        cart_items.each do |cart_item|
          OrderItem.build_from_cart_item(cart_item, order).save!
        end

        order
      end
    end

    private

    attr_reader :stripe_session, :cart

    def order_attributes
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
        # Both addresses come from the shared mapping (billing fails open to
        # nils - display-only, must never cost a paid order); the webhook path
        # merges the same call so the two can't drift.
        **Checkout::SessionDetails.order_address_attributes(stripe_session),
        # The zone the order was priced against, not the zone of the collected
        # address: the order records what the customer was charged. Nil falls
        # back to deriving from the postcode (see Order#delivery_zone).
        shipping_zone: Checkout::SessionDetails.shipping_zone(stripe_session)
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
