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
