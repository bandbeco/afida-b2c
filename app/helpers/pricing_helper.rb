module PricingHelper
  # Formats price display for cart items and order items
  # Pack-priced items: "£15.99 / pack"
  # Unit-priced items: "£0.0320 / unit"
  #
  # @param item [CartItem, OrderItem] an item responding to pack_priced?, pack_price, unit_price
  # @return [String] formatted price display string
  def format_price_display(item)
    if item.pack_priced?
      "#{number_to_currency(item.pack_price, unit: '£')} / pack"
    else
      "#{number_to_currency(item.unit_price, unit: '£', precision: 4)} / unit"
    end
  end

  # The standard delivery price, formatted for display (e.g. "£6.99").
  # Single source of truth: Shipping::STANDARD_COST. Use this everywhere a
  # delivery price is shown so display text can never drift from the charge.
  #
  # @return [String] formatted delivery price, e.g. "£6.99"
  def delivery_price_display
    Shipping.formatted_standard_cost
  end

  # The delivery price qualified as a starting point, e.g. "from £6.99".
  #
  # STANDARD_COST is the MAINLAND price; Northern Ireland, the Scottish Highlands
  # and the islands pay a higher flat rate instead (see ShippingZone). Copy that states a
  # flat price without this qualifier promises a rate we don't charge everyone,
  # which is the same class of claim the free-delivery copy had to be corrected
  # for. Use this wherever a price is quoted before a destination is known.
  #
  # @return [String] e.g. "from £6.99"
  def delivery_price_from_display
    "from #{delivery_price_display}"
  end

  # The off-mainland delivery price, formatted for display (e.g. "£25.00").
  #
  # Every off-mainland zone shares one rate, so :highlands stands for all of them
  # (ShippingZone pins that they agree). Derived rather than restated so the
  # published delivery table cannot advertise a price we no longer charge.
  #
  # @return [String] e.g. "£25.00"
  def off_mainland_delivery_price_display
    ActiveSupport::NumberHelper.number_to_currency(
      Shipping.cost_for_zone_in_pounds(:highlands), unit: "£"
    )
  end

  # Formats quantity display for cart items and order items
  # Pack-priced items: "30 packs (15,000 units)" - quantity IS packs, units = quantity * pac_size
  # Unit-priced items: "5,000 units" - quantity IS units
  #
  # @param item [CartItem, OrderItem] an item responding to pack_priced?, pac_size, quantity
  # @return [String] formatted quantity display string
  def format_quantity_display(item)
    # Samples always ship as a single unit, regardless of the product's pack pricing
    return "1 unit" if item.sample?

    if item.pack_priced?
      # quantity is number of packs, calculate total units
      packs = item.quantity
      total_units = packs * item.pac_size
      "#{number_with_delimiter(packs)} #{'pack'.pluralize(packs)} (#{number_with_delimiter(total_units)} units)"
    else
      "#{number_with_delimiter(item.quantity)} units"
    end
  end
end
