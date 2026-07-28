module Checkout
  # The single home for deriving the non-money Order fields from a completed Stripe
  # Checkout session: the shipping address and the promotion code. Both
  # order-creation paths (Checkout::OrderCreator on the success redirect and the
  # Stripe webhook fallback) call these, so the two can't drift in how they read a
  # session. Money figures live in SessionAmounts; the required-field presence check
  # lives in Order.required_shipping_values.
  module SessionDetails
    module_function

    # Maps the session's collected shipping details to the shipping_* hash the Order
    # is built from, or {} when the session carries no shipping details (a permanent
    # failure both callers guard via Order.required_shipping_values). Uses
    # to_hash.with_indifferent_access for defensive hash access (Stripe objects nest
    # inconsistently across API versions).
    def shipping_address(session)
      session_hash = session.to_hash.with_indifferent_access

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

    # The delivery zone the order was PRICED against, recorded in session metadata
    # by SessionBuilder, or nil when absent (sessions created before this existed).
    #
    # This is deliberately not re-derived from the delivered-to postcode: the two
    # can differ, because delivery is priced from the cart-page postcode one screen
    # before Stripe collects the real address. The order records what the customer
    # was actually charged, so the priced zone is the authority; Order#delivery_zone
    # falls back to the postcode when this is missing.
    def shipping_zone(session)
      zone = session.metadata&.[]("shipping_zone").presence
      return nil unless zone

      zone if ShippingZone.deliverable?(zone.to_sym)
    end

    # The type of the payment method that actually paid the session ("card",
    # "link", ...), read from the expanded payment_intent; callers must
    # retrieve the session with expand: ["payment_intent.payment_method"].
    # The session's payment_method_types is the CONFIGURED list, not the
    # customer's choice: custom mode configures ["card", "link"], so its first
    # entry says nothing about how the customer paid. Falls back to "card"
    # when no expanded intent is present (a zero-total no_payment_required
    # session has no payment at all, and an unexpanded retrieve returns an id
    # string), matching what the event recorded before the type was read.
    def payment_method_type(session)
      session.try(:payment_intent).try(:payment_method).try(:type) || "card"
    end

    # The Stripe-entered promotion code (the human-typed string, e.g. "SUMMER20"), or
    # nil when none was applied. Deliberately does NOT rescue an unexpected Stripe
    # shape: each caller owns that policy. OrderCreator lets a NoMethodError surface
    # so a success-path failure is visible (the webhook fallback still creates the
    # order); the webhook rescues it to nil so a malformed discount can't fail a
    # paid order over a cosmetic field.
    def promotion_code(session)
      session
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
