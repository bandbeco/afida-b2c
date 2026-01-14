module CartHelper
  # Unified entry point for quantity dropdown options
  # Delegates to the appropriate helper based on item type
  def quantity_options_for_cart_item(cart_item)
    if cart_item.configured?
      branded_quantity_options_for_select(cart_item)
    else
      standard_quantity_options_for_select(cart_item)
    end
  end

  # Generate quantity options for standard (pack-priced) products
  # Returns array of [label, value] pairs for options_for_select
  def standard_quantity_options_for_select(cart_item)
    pac_size = cart_item.product.pac_size || 1
    pack_options = (1..10).to_a + [ 30, 40, 50, 60 ]

    # Include current quantity if it's not in the standard options
    pack_options << cart_item.quantity unless pack_options.include?(cart_item.quantity)
    pack_options.sort!.uniq!

    pack_options.map do |num_packs|
      total_units = num_packs * pac_size
      label = "#{num_packs} #{num_packs == 1 ? 'pack' : 'packs'} (#{number_with_delimiter(total_units)} units)"
      [ label, num_packs ]
    end
  end

  # Generate quantity options for branded (configured) products with savings percentages
  # Uses database pricing tiers as the single source of truth (matches configurator page)
  # Returns array of [label, value] pairs for options_for_select
  def branded_quantity_options_for_select(cart_item)
    return [] unless cart_item.configured?

    size = cart_item.configuration["size"]
    product = cart_item.product
    pricing_service = BrandedProductPricingService.new(product)

    # Get available quantities from database (same source as configurator page)
    quantities = pricing_service.available_quantities(size)
    return [] if quantities.empty?

    # Include current quantity if not already in the list (e.g., legacy orders)
    quantities << cart_item.quantity unless quantities.include?(cart_item.quantity)
    quantities.sort!.uniq!

    # Get base price (lowest tier) for savings calculation
    base_result = pricing_service.calculate(size: size, quantity: quantities.first)
    base_price = base_result.success? ? base_result.price_per_unit : nil

    quantities.filter_map do |qty|
      result = pricing_service.calculate(size: size, quantity: qty)
      next unless result.success?

      label = "#{number_with_delimiter(qty)} units"

      # Add savings percentage if better than base price
      if base_price && result.price_per_unit < base_price
        savings_pct = ((base_price - result.price_per_unit) / base_price * 100).round
        label += " - save #{savings_pct}%"
      end

      [ label, qty ]
    end
  end
end
