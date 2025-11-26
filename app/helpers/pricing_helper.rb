module PricingHelper
  # Formats price display for cart items and order items
  # Pack-priced items: "£15.99 / pack (£0.0320 / unit)"
  # Unit-priced items: "£0.0320 / unit"
  #
  # @param item [CartItem, OrderItem] an item responding to pack_priced?, pack_price, unit_price
  # @return [String] formatted price display string
  def format_price_display(item)
    if item.pack_priced?
      pack = number_to_currency(item.pack_price, unit: "£")
      unit = number_to_currency(item.unit_price, unit: "£", precision: 4)
      "#{pack} / pack (#{unit} / unit)"
    else
      unit = number_to_currency(item.unit_price, unit: "£", precision: 4)
      "#{unit} / unit"
    end
  end

  # Formats quantity display for cart items and order items
  # Pack-priced items: "30 packs (15,000 units)"
  # Unit-priced items: "5,000 units"
  #
  # @param item [CartItem, OrderItem] an item responding to pack_priced?, pac_size, quantity
  # @return [String] formatted quantity display string
  def format_quantity_display(item)
    if item.pack_priced?
      packs = (item.quantity.to_f / item.pac_size).ceil
      units = number_with_delimiter(item.quantity)
      "#{number_with_delimiter(packs)} #{'pack'.pluralize(packs)} (#{units} units)"
    else
      "#{number_with_delimiter(item.quantity)} units"
    end
  end
end
