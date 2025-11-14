# Branded Product Pricing
puts "Creating branded product pricing..."

# Find branded products category
branded_category = Category.find_by(slug: "branded-products")
unless branded_category
  puts "ERROR: Branded Products category not found"
  return
end

# Define all branded product templates with min quantities
templates = [
  { name: "Double Wall Hot Cups", slug: "double-wall-branded-cups", min_qty: 5000, sort: 1, has_pricing: true },
  { name: "Single Wall Hot Cups", slug: "single-wall-branded-cups", min_qty: 30000, sort: 2, has_pricing: true },
  { name: "Single Wall Cold Cups", slug: "single-wall-cold-branded-cups", min_qty: 30000, sort: 3, has_pricing: false },
  { name: "Clear Recyclable Cups", slug: "clear-recyclable-branded-cups", min_qty: 30000, sort: 4, has_pricing: false },
  { name: "Ice Cream Cups", slug: "ice-cream-branded-cups", min_qty: 50000, sort: 5, has_pricing: false },
  { name: "Greaseproof Paper", slug: "greaseproof-branded-paper", min_qty: 6000, sort: 6, has_pricing: false },
  { name: "Pizza Boxes", slug: "pizza-boxes-branded", min_qty: 5000, sort: 7, has_pricing: false },
  { name: "Kraft Containers", slug: "kraft-containers-branded", min_qty: 10000, sort: 8, has_pricing: false },
  { name: "Kraft Bags", slug: "kraft-bags-branded", min_qty: 10000, sort: 9, has_pricing: false }
]

# Create all template products
templates.each do |template_data|
  product = Product.find_or_create_by!(slug: template_data[:slug]) do |p|
    p.name = template_data[:name]
    p.product_type = "customizable_template"
    p.category = branded_category
    p.description = "Custom branded #{template_data[:name].downcase} with your design. Minimum order: #{template_data[:min_qty].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units"
    p.active = true
    p.position = template_data[:sort]
  end

  # Create placeholder variant
  product.variants.find_or_create_by!(sku: "PLACEHOLDER-#{template_data[:slug].upcase}") do |v|
    v.name = 'Placeholder'
    v.price = 0.01
    v.stock_quantity = 0
    v.active = true
  end

  puts "  ✓ #{product.name} (min: #{template_data[:min_qty]})"
end

# Get products with pricing
single_wall_branded = Product.find_by(slug: "single-wall-branded-cups")
double_wall_branded = Product.find_by(slug: "double-wall-branded-cups")

# Pricing from CSV: Single Wall
pricing_data_sw = [
  { size: "8oz", quantity: 1000, price: 0.26, case_qty: 1000 },
  { size: "8oz", quantity: 2000, price: 0.20, case_qty: 1000 },
  { size: "8oz", quantity: 5000, price: 0.15, case_qty: 1000 },
  { size: "8oz", quantity: 10000, price: 0.12, case_qty: 1000 },
  { size: "8oz", quantity: 20000, price: 0.11, case_qty: 1000 },
  { size: "8oz", quantity: 30000, price: 0.10, case_qty: 1000 },

  { size: "12oz", quantity: 1000, price: 0.28, case_qty: 1000 },
  { size: "12oz", quantity: 5000, price: 0.17, case_qty: 1000 },
  { size: "12oz", quantity: 10000, price: 0.14, case_qty: 1000 },
  { size: "12oz", quantity: 20000, price: 0.12, case_qty: 1000 },
  { size: "12oz", quantity: 30000, price: 0.11, case_qty: 1000 },

  { size: "16oz", quantity: 1000, price: 0.30, case_qty: 1000 },
  { size: "16oz", quantity: 5000, price: 0.20, case_qty: 1000 },
  { size: "16oz", quantity: 10000, price: 0.17, case_qty: 1000 },
  { size: "16oz", quantity: 20000, price: 0.15, case_qty: 1000 },
  { size: "16oz", quantity: 30000, price: 0.14, case_qty: 1000 }
]

pricing_data_sw.each do |data|
  single_wall_branded.branded_product_prices.find_or_create_by!(
    size: data[:size],
    quantity_tier: data[:quantity]
  ) do |price|
    price.price_per_unit = data[:price]
    price.case_quantity = data[:case_qty]
  end
end

puts "  Single Wall Branded Cups: #{pricing_data_sw.size} pricing tiers created"

# Create Double Wall Branded Cups template
double_wall_branded = Product.find_or_create_by!(slug: "double-wall-branded-cups") do |product|
  product.name = "Double Wall Branded Cups"
  product.product_type = "customizable_template"
  product.category = branded_category
  product.description = "Premium double-wall insulated cups with your custom branding. No sleeve needed!"
  product.active = true
  product.position = 2
end

# Pricing from CSV: Double Wall
pricing_data_dw = [
  { size: "8oz", quantity: 1000, price: 0.30, case_qty: 500 },
  { size: "8oz", quantity: 2000, price: 0.25, case_qty: 500 },
  { size: "8oz", quantity: 5000, price: 0.18, case_qty: 500 },
  { size: "8oz", quantity: 10000, price: 0.15, case_qty: 500 },
  { size: "8oz", quantity: 20000, price: 0.11, case_qty: 500 },
  { size: "8oz", quantity: 30000, price: 0.10, case_qty: 500 },

  { size: "12oz", quantity: 1000, price: 0.32, case_qty: 500 },
  { size: "12oz", quantity: 5000, price: 0.20, case_qty: 500 },
  { size: "12oz", quantity: 10000, price: 0.17, case_qty: 500 },
  { size: "12oz", quantity: 20000, price: 0.13, case_qty: 500 },
  { size: "12oz", quantity: 30000, price: 0.12, case_qty: 500 },

  { size: "16oz", quantity: 1000, price: 0.34, case_qty: 500 },
  { size: "16oz", quantity: 5000, price: 0.22, case_qty: 500 },
  { size: "16oz", quantity: 10000, price: 0.19, case_qty: 500 },
  { size: "16oz", quantity: 20000, price: 0.15, case_qty: 500 },
  { size: "16oz", quantity: 30000, price: 0.14, case_qty: 500 }
]

pricing_data_dw.each do |data|
  double_wall_branded.branded_product_prices.find_or_create_by!(
    size: data[:size],
    quantity_tier: data[:quantity]
  ) do |price|
    price.price_per_unit = data[:price]
    price.case_quantity = data[:case_qty]
  end
end

puts "  Double Wall Branded Cups: #{pricing_data_dw.size} pricing tiers created"

# Create placeholder variants for template products (required by cart system)
[ single_wall_branded, double_wall_branded ].each do |product|
  product.variants.find_or_create_by!(sku: "PLACEHOLDER-#{product.slug.upcase}") do |v|
    v.name = 'Placeholder'
    v.price = 0.01
    v.stock_quantity = 0
    v.active = true
  end
end

puts "Branded product pricing created successfully!"
puts "  Total pricing entries: #{pricing_data_sw.size + pricing_data_dw.size}"
puts "  Placeholder variants created for template products"
