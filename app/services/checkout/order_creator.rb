module Checkout
  # Builds the Order row (and its items) for a paid Checkout Session: the
  # row-building part of a checkout completion (see CONTEXT.md), used only by
  # Checkout::Completion. The cart is consumed inside the same transaction as
  # the order so a failed item copy leaves the customer their cart, and a
  # committed order can never coexist with a still-full cart.
  #
  # The cart may be nil or empty: money has moved either way, so an item-less
  # paid order is still recorded (Stripe holds the line items) and the caller
  # reports it for ops to reconcile.
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
        cart&.cart_items&.destroy_all

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
        # nils - display-only, must never cost a paid order).
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
      return @cart_items if defined?(@cart_items)

      @cart_items = cart ? cart.cart_items.includes(Checkout::CART_ITEM_INCLUDES).load : []
    end

    def user
      return @user if defined?(@user)

      @user = User.find_by(id: stripe_session.client_reference_id)
    end

    # The Welcome discount's code from metadata, else the Stripe-entered
    # promotion code. The promotion code is display-only (the money is already
    # correct from SessionAmounts), so an unexpected discount shape is reported
    # and recorded as no code rather than failing a paid order: there is no
    # second completion channel left to fail over to.
    def discount_code
      stripe_session.metadata&.[]("discount_code").presence ||
        Checkout::SessionDetails.promotion_code(stripe_session)
    rescue NoMethodError => e
      Sentry.capture_exception(e, extra: { stripe_session_id: stripe_session.id })
      Rails.logger.error("Unreadable promotion code on session #{stripe_session.id}: #{e.message}")
      nil
    end
  end
end
