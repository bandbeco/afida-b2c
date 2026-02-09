class BrandedProductPricingService
  Result = Struct.new(:success, :price_per_unit, :total_price, :quantity, :case_quantity, :cases_needed, :error, keyword_init: true) do
    def success?
      success
    end
  end

  MINIMUM_ORDER_QUANTITY = 1000

  def initialize(product)
    @product = product
  end

  def calculate(size:, quantity:)
    return error_result("Size and quantity are required") if size.blank? || quantity.blank?
    return error_result("Quantity below minimum order") if quantity < MINIMUM_ORDER_QUANTITY

    pricing = BrandedProductPrice.find_for_configuration(@product, size, quantity)
    return error_result("No pricing found for this configuration") unless pricing

    Result.new(
      success: true,
      price_per_unit: pricing.price_per_unit,
      total_price: pricing.price_per_unit * quantity,
      quantity: quantity,
      case_quantity: pricing.case_quantity,
      cases_needed: (quantity.to_f / pricing.case_quantity).ceil
    )
  end

  def available_sizes
    # Sort sizes: numerically for oz-based sizes (8oz, 12oz, 16oz),
    # alphabetically for text-based variants (A3 Kraft 1 Colour, A4 White 2 Colours)
    # Use map instead of pluck to utilize eager-loaded association
    @product.branded_product_prices.map(&:size).uniq.sort_by { |size| [ size.to_i, size ] }
  end

  def available_quantities(size)
    # Use select and map instead of where/pluck to utilize eager-loaded association
    @product.branded_product_prices
            .select { |p| p.size == size }
            .map(&:quantity_tier)
            .sort
  end

  private

  def error_result(message)
    Result.new(success: false, error: message)
  end
end
