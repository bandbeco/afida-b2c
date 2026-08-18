module Checkout
  # The single home for deriving the non-money Order fields from a completed Stripe
  # Checkout session: the shipping and billing addresses and the promotion code. Both
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
    # inconsistently across API versions); with_indifferent_access deep-converts, so
    # nested hashes need no further coercion.
    def shipping_address(session)
      shipping_address_from(session.to_hash.with_indifferent_access)
    end

    # Maps the session's customer details (name + address) to the billing_* hash the
    # Order is built from, or {} when absent. Unlike shipping, billing does NOT live
    # under collected_information: billing_address_collection populates
    # customer_details on the completed session. Must fail open with no counterpart
    # to Order.required_shipping_values - sessions predating billing collection,
    # Link/wallet flows reusing a stored address, and zero-total sessions can all
    # legitimately carry no billing address, and none of that may block an order
    # the customer has already paid for.
    def billing_address(session)
      billing_address_from(session.to_hash.with_indifferent_access)
    end

    # Both addresses mapped to the Order's shipping_*/billing_* column names in
    # one pass: the single source both order-creation paths merge into their
    # Order.create! attributes, so a new address field can never be wired into
    # the success redirect but forgotten on the webhook (or vice versa). One
    # to_hash conversion covers both reads - the expanded session is large
    # (line items, payment intent), so callers should not convert it twice.
    def order_address_attributes(session)
      session_hash = session.to_hash.with_indifferent_access
      shipping = shipping_address_from(session_hash)
      billing = billing_address_from(session_hash)

      {
        shipping_name: shipping[:name],
        shipping_address_line1: shipping[:line1],
        shipping_address_line2: shipping[:line2],
        shipping_city: shipping[:city],
        shipping_postal_code: shipping[:postal_code],
        shipping_country: shipping[:country],
        billing_name: billing[:name],
        billing_address_line1: billing[:line1],
        billing_address_line2: billing[:line2],
        billing_city: billing[:city],
        billing_postal_code: billing[:postal_code],
        billing_country: billing[:country]
      }
    end

    def shipping_address_from(session_hash)
      shipping = session_hash.dig(:collected_information, :shipping_details)
      return {} unless shipping

      extract_address(name: shipping[:name], address: shipping[:address])
    end

    def billing_address_from(session_hash)
      customer_details = session_hash[:customer_details]
      return {} unless customer_details

      extract_address(name: customer_details[:name], address: customer_details[:address])
    end

    def extract_address(name:, address:)
      return {} unless address

      {
        name: name,
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
      promo = session
        .total_details
        &.breakdown
        &.discounts
        &.first
        &.discount
        &.promotion_code

      # Both order-creation paths expand total_details.breakdown (without it the
      # breakdown is nil and no code is readable at all), but expanding the breakdown
      # does NOT expand the nested promotion_code: Stripe returns that as a bare
      # "promo_..." ID string, so resolve it. Calling .code on the String returned nil,
      # silently dropping the code from 13 of 22 live welcome-coupon orders and hiding
      # repeat use of a one-time coupon. An already-expanded object is still handled.
      return resolve_promotion_code(promo) if promo.is_a?(String)

      promo&.code
    end

    # A cosmetic field must never fail a paid order, so an unresolvable ID degrades to
    # nil (the same value callers already treat as "no code"). The traversal in
    # promotion_code still propagates an unexpected session SHAPE; only the network
    # lookup is softened here.
    def resolve_promotion_code(promotion_code_id)
      Stripe::PromotionCode.retrieve(promotion_code_id)&.code
    rescue StandardError => e
      # Deliberately broader than Stripe::StripeError. This runs while creating an
      # order the customer has ALREADY PAID for, purely to recover a display field, so
      # nothing it can raise (a socket error escaping the gem, a shape change) may cost
      # the order. Callers already treat nil as "no code recorded".
      Rails.logger.warn("Could not resolve promotion code #{promotion_code_id}: #{e.class}: #{e.message}")
      nil
    end
  end
end
