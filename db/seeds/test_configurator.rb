# Quick seed for testing the configurator
puts 'Creating test data for configurator...'

# Create branded category
branded_cat = Category.find_or_create_by!(slug: 'branded-products') do |c|
  c.name = 'Branded Products'
  c.description = 'Custom branded packaging'
end

# Create template product
template = Product.find_or_create_by!(slug: 'double-wall-branded-cups') do |p|
  p.name = 'Double Wall Branded Cups'
  p.product_type = 'customizable_template'
  p.category = branded_cat
  p.description = 'Premium double-wall cups with your custom design'
  p.active = true
  p.sort_order = 1
end

# Create pricing matrix
pricing = [
  { size: '8oz', qty: 1000, price: 0.30, case: 500 },
  { size: '8oz', qty: 2000, price: 0.25, case: 500 },
  { size: '8oz', qty: 5000, price: 0.18, case: 500 },
  { size: '12oz', qty: 1000, price: 0.32, case: 500 },
  { size: '12oz', qty: 5000, price: 0.20, case: 500 },
  { size: '16oz', qty: 1000, price: 0.34, case: 500 }
]

pricing.each do |p|
  template.branded_product_prices.find_or_create_by!(
    size: p[:size],
    quantity_tier: p[:qty]
  ) do |price|
    price.price_per_unit = p[:price]
    price.case_quantity = p[:case]
  end
end

# Create placeholder variant (required by cart_items relationship)
template.variants.find_or_create_by!(sku: 'P-DWBC') do |v|
  v.name = 'Placeholder'
  v.price = 0.01
  v.stock_quantity = 0
  v.active = true
end

puts "✓ Created template product: #{template.name}"
puts "✓ Created #{template.branded_product_prices.count} pricing entries"
puts "✓ Created placeholder variant"
puts "\nVisit: http://localhost:3000/product/double-wall-branded-cups"
