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
        raise Checkout::MissingShippingDetails.new("Shipping details are required", stripe_session)
      end

      # Check for cart vs session mismatch before proceeding
      detect_cart_session_mismatch if cart.present?

      # Resolved before the transaction opens: reading the promotion code can
      # call Stripe, and a network round-trip must not hold a connection open.
      attributes = order_attributes

      ApplicationRecord.transaction do
        order = Order.create!(attributes)

        cart_items.each do |cart_item|
          OrderItem.build_from_cart_item(cart_item, order).save!
        end
        # The whole cart is consumed, including any item added after the
        # session was priced. The redirect is reached from a page that would
        # have repriced on such a change; the webhook has no such guard.
        # detect_cart_session_mismatch now reports such cases to Sentry but
        # doesn't block order creation; see #322 for the full fix.
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
        email: stripe_session.customer_details&.email,
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

    # Detect cart vs session mismatch: items added to the cart after pricing
    # would be copied into the order unpaid. Compare cart item count and subtotal
    # against the session's paid product line items (excluding shipping).
    # This is detect-only (#322) and must not fail a paid order.
    def detect_cart_session_mismatch
      return unless cart.present?

      session_product_lines = session_product_line_items
      cart_item_count = cart_items.sum(&:quantity)
      session_item_count = session_product_lines.sum { |item| item.quantity || 0 }

      # Get subtotals in pence for comparison
      cart_subtotal_pence = (cart_items.sum { |item| item.price * item.quantity } * 100).round
      session_subtotal_pence = session_product_lines.sum(&:amount_subtotal)

      if cart_item_count != session_item_count || cart_subtotal_pence != session_subtotal_pence
        Rails.logger.error(
          "[Checkout completion] Cart/session mismatch on session #{stripe_session.id}: " \
          "cart has #{cart_item_count} items (£#{cart_subtotal_pence / 100.0}), " \
          "session has #{session_item_count} items (£#{session_subtotal_pence / 100.0})"
        )
        Sentry.capture_message(
          "Cart/session mismatch: items added after pricing",
          level: :error,
          extra: {
            stripe_session_id: stripe_session.id,
            cart_id: cart.id,
            cart_item_count: cart_item_count,
            cart_subtotal_pence: cart_subtotal_pence,
            session_item_count: session_item_count,
            session_subtotal_pence: session_subtotal_pence
          }
        )
      end
    rescue StandardError => e
      # Detect-only: a diagnostic failure must not block order creation.
      # Report and continue, the same way an unreadable promotion code is handled.
      Sentry.capture_exception(e, extra: { stripe_session_id: stripe_session.id })
      Rails.logger.error("Cart/session mismatch check failed on session #{stripe_session.id}: #{e.message}")
    end

    # Product line items from the session (excluding shipping). Uses the same
    # pagination logic as SessionAmounts to handle >10 line items.
    def session_product_line_items
      return @session_product_line_items if defined?(@session_product_line_items)

      embedded = stripe_session.line_items
      page_one = embedded&.data || []
      all_lines =
        if embedded.respond_to?(:has_more) && embedded.has_more
          page_one + Checkout::SessionLineItems.list(stripe_session.id, starting_after: page_one.last&.id)
        else
          page_one
        end

      @session_product_line_items = all_lines.reject { |item| Checkout::SessionLineItems.shipping?(item) }
    end
  end
end
