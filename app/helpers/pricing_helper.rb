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

  # Formats quantity display for cart items and order items
  # Pack-priced items: "30 packs (15,000 units)" - quantity IS packs, units = quantity * pac_size
  # Unit-priced items: "5,000 units" - quantity IS units
  #
  # @param item [CartItem, OrderItem] an item responding to pack_priced?, pac_size, quantity
  # @return [String] formatted quantity display string
  def format_quantity_display(item)
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
