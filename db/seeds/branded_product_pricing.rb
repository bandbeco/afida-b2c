# Branded Product Pricing
puts "Creating branded product pricing..."

# Find branded products category
branded_category = Category.find_by(slug: "branded-products")
unless branded_category
  puts "ERROR: Branded Products category not found"
  return
end

# =============================================================================
# BRANDED PRODUCT TEMPLATES
# Comment/uncomment products here - this is the ONLY place you need to edit
# =============================================================================
templates = [
  {
    name: "Double Wall Coffee Cups",
    slug: "double-wall-coffee-cups",
    sku: "P-DWCC",
    min_qty: 5000,
    sort: 1,
    case_qty: 500,
    pricing: [
      { size: "8oz", quantity: 1000, price: 0.30 },
      { size: "8oz", quantity: 2000, price: 0.25 },
      { size: "8oz", quantity: 5000, price: 0.18 },
      { size: "8oz", quantity: 10000, price: 0.15 },
      { size: "8oz", quantity: 20000, price: 0.11 },
      { size: "8oz", quantity: 30000, price: 0.10 },
      { size: "12oz", quantity: 1000, price: 0.32 },
      { size: "12oz", quantity: 5000, price: 0.20 },
      { size: "12oz", quantity: 10000, price: 0.17 },
      { size: "12oz", quantity: 20000, price: 0.13 },
      { size: "12oz", quantity: 30000, price: 0.12 },
      { size: "16oz", quantity: 1000, price: 0.34 },
      { size: "16oz", quantity: 5000, price: 0.22 },
      { size: "16oz", quantity: 10000, price: 0.19 },
      { size: "16oz", quantity: 20000, price: 0.15 },
      { size: "16oz", quantity: 30000, price: 0.14 }
    ]
  }

  # {
  #   name: "Single Wall Hot Cups",
  #   slug: "single-wall-hot-cups",
  #   sku: "P-SWHC",
  #   min_qty: 30000,
  #   sort: 2,
  #   case_qty: 1000,
  #   pricing: [
  #     { size: "8oz", quantity: 1000, price: 0.26 },
  #     { size: "8oz", quantity: 2000, price: 0.20 },
  #     { size: "8oz", quantity: 5000, price: 0.15 },
  #     { size: "8oz", quantity: 10000, price: 0.12 },
  #     { size: "8oz", quantity: 20000, price: 0.11 },
  #     { size: "8oz", quantity: 30000, price: 0.10 },
  #     { size: "12oz", quantity: 1000, price: 0.28 },
  #     { size: "12oz", quantity: 5000, price: 0.17 },
  #     { size: "12oz", quantity: 10000, price: 0.14 },
  #     { size: "12oz", quantity: 20000, price: 0.12 },
  #     { size: "12oz", quantity: 30000, price: 0.11 },
  #     { size: "16oz", quantity: 1000, price: 0.30 },
  #     { size: "16oz", quantity: 5000, price: 0.20 },
  #     { size: "16oz", quantity: 10000, price: 0.17 },
  #     { size: "16oz", quantity: 20000, price: 0.15 },
  #     { size: "16oz", quantity: 30000, price: 0.14 }
  #   ]
  # },

  # { name: "Single Wall Cold Cups", slug: "single-wall-cold-cups", sku: "P-SWCC", min_qty: 30000, sort: 3, case_qty: 1000, pricing: [] },
  # { name: "Clear Recyclable Cups", slug: "clear-recyclable-cups", sku: "P-CRC", min_qty: 30000, sort: 4, case_qty: 1000, pricing: [] },
  # { name: "Ice Cream Cups", slug: "ice-cream-cups", sku: "P-ICC", min_qty: 50000, sort: 5, case_qty: 500, pricing: [] },
  # { name: "Greaseproof Paper", slug: "greaseproof-paper", sku: "P-GP", min_qty: 6000, sort: 6, case_qty: 1000, pricing: [] },
  # { name: "Pizza Boxes", slug: "pizza-boxes", sku: "P-PB", min_qty: 5000, sort: 7, case_qty: 100, pricing: [] },
  # { name: "Kraft Containers", slug: "kraft-containers", sku: "P-KC", min_qty: 10000, sort: 8, case_qty: 300, pricing: [] },
  # { name: "Kraft Bags", slug: "kraft-bags", sku: "P-KB", min_qty: 10000, sort: 9, case_qty: 250, pricing: [] }
]

# =============================================================================
# PROCESSING (no need to edit below this line)
# =============================================================================

total_pricing_entries = 0

templates.each do |template_data|
  # Create the product (match on slug AND product_type to allow same slug as standard products)
  product = Product.find_or_create_by!(slug: template_data[:slug], product_type: "customizable_template") do |p|
    p.name = template_data[:name]
    p.sku = template_data[:sku]
    p.price = 0.01 # Placeholder - actual price calculated from pricing tiers
    p.category = branded_category
    p.description_short = "Custom branded #{template_data[:name].downcase} with your design. Minimum order: #{template_data[:min_qty].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units"
    p.description_standard = "Custom branded #{template_data[:name].downcase} with your design. Minimum order: #{template_data[:min_qty].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units"
    p.description_detailed = "Custom branded #{template_data[:name].downcase} with your design. Minimum order: #{template_data[:min_qty].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units. Perfect for your business."
    p.active = true
    p.position = template_data[:sort]
    p.stock_quantity = 0
  end

  # Create pricing tiers if defined
  if template_data[:pricing].present?
    template_data[:pricing].each do |price_data|
      product.branded_product_prices.find_or_create_by!(
        size: price_data[:size],
        quantity_tier: price_data[:quantity]
      ) do |price|
        price.price_per_unit = price_data[:price]
        price.case_quantity = template_data[:case_qty]
      end
    end
    total_pricing_entries += template_data[:pricing].size
    puts "  ✓ #{product.name} (min: #{template_data[:min_qty]}, #{template_data[:pricing].size} pricing tiers)"
  else
    puts "  ✓ #{product.name} (min: #{template_data[:min_qty]}, no pricing)"
  end
end

puts "Branded product pricing created successfully!"
puts "  Total products: #{templates.size}"
puts "  Total pricing entries: #{total_pricing_entries}"
