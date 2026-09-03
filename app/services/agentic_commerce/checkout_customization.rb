module AgenticCommerce
  # Answers Stripe's checkout customization hook for an agent checkout: which
  # delivery option to offer and which tax rate to apply to each line item.
  #
  # A pure function of the hook request. Stripe may call it more than once for
  # the same checkout (agents retry), so nothing here writes or depends on
  # state beyond the cached UK VAT rate id. Prices come from the same
  # Shipping / ShippingZone rules the website quotes, so an agent customer is
  # charged exactly what the cart page would have shown them.
  class CheckoutCustomization
    CURRENCY = Shipping::CURRENCY

    def initialize(data)
      @data = data || {}
    end

    def response
      { shipping_options: shipping_options, line_items: line_items }
    end

    private

    attr_reader :data

    # One option, or none when we do not deliver to the address. Returning no
    # options is how the hook refuses a destination: non-GB countries and the
    # Crown Dependencies (see ShippingZone::UNDELIVERABLE_AREAS) get nothing
    # rather than a mainland price we could not honour.
    def shipping_options
      return [] unless Shipping::ALLOWED_COUNTRIES.include?(address["country"])
      return [] if resolved_zone == :undeliverable

      [ { shipping_rate_data: shipping_rate_data } ]
    end

    def shipping_rate_data
      free = Shipping.free_shipping?(zone: zone, subtotal: subtotal_in_pounds)
      {
        display_name: "#{free ? 'Free' : 'Standard'} delivery (#{ShippingZone.transit_label(zone)})",
        fixed_amount: { amount: free ? 0 : Shipping.cost_for_zone(zone), currency: CURRENCY },
        tax_behavior: "exclusive",
        delivery_estimate: delivery_estimate
      }
    end

    # Mainland is next working day; every off-mainland zone carries the one
    # 2-4 working day promise ShippingZone::OFF_MAINLAND_TRANSIT_LABEL makes.
    def delivery_estimate
      extra_days = ShippingZone.transit_days(zone)
      minimum = extra_days.zero? ? 1 : 2
      {
        minimum: { unit: "business_day", value: minimum },
        maximum: { unit: "business_day", value: 1 + extra_days }
      }
    end

    # Manual tax rates are only accepted when Stripe Tax is off for the
    # checkout; when it is on, Stripe calculates tax itself and our rates
    # would be rejected, so send none.
    def line_items
      return [] if data.dig("automatic_tax", "enabled")

      rate_id = tax_rate_id
      line_item_details.map { |item| { id: item["id"], tax_rates: [ { rate: rate_id } ] } }
    end

    def tax_rate_id
      Checkout::StripeTaxRateProvider.new.tax_rate.id
    end

    def address
      data.dig("shipping_details", "address") || {}
    end

    def resolved_zone
      @resolved_zone ||= ShippingZone.for(address["postal_code"])
    end

    # An unparseable GB postcode is priced as mainland, as SessionBuilder#zone
    # does for the website: refusing a paying customer over a postcode format
    # is worse than the small risk of under-charging an off-mainland order.
    def zone
      ShippingZone.deliverable?(resolved_zone) ? resolved_zone : :mainland
    end

    def line_item_details
      data["line_item_details"] || []
    end

    def subtotal_in_pounds
      pence = data["amount_subtotal"] || line_item_details.sum { |item| item["amount_subtotal"].to_i }
      BigDecimal(pence.to_s) / 100
    end
  end
end
