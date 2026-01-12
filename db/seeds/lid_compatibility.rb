# Seed lid compatibility relationships between cups and lids
puts "Populating lid compatibility data..."

# Clear existing data
ProductCompatibleLid.destroy_all
puts "Cleared existing compatibility data"

# Define hot cup product names (paper-based hot beverage cups)
hot_cup_names = [
  "Single Wall Coffee Cups",
  "Double Wall Coffee Cups",
  "Ripple Wall Coffee Cups"
]

# Define hot lid product names
hot_lid_names = [
  "Coffee Cup Sip Lids"
]

# Define cold cup product names (plastic/clear cups)
cold_cup_names = [
  "Smoothie Cups"
]

# Define cold lid product names
cold_lid_names = [
  "Smoothie Dome Lids",
  "Smoothie Flat Lids"
]

# Populate hot cup → hot lid relationships
# Include both standard and branded (customizable_template) products
hot_cups = Product.where(name: hot_cup_names)
hot_lids = Product.where(name: hot_lid_names, product_type: [ nil, 'standard' ])

hot_cups.each do |cup|
  type_label = cup.product_type == 'customizable_template' ? ' (branded)' : ''
  puts "\nProcessing cup: #{cup.name}#{type_label}"

  hot_lids.each_with_index do |lid, index|
    compatibility = ProductCompatibleLid.create!(
      product: cup,
      compatible_lid: lid,
      sort_order: index,
      default: index == 0 # First lid is default
    )
    puts "  ✓ Added compatible lid: #{lid.name} (default: #{compatibility.default})"
  end
end

# Populate cold cup → cold lid relationships
# Include both standard and branded (customizable_template) products
cold_cups = Product.where(name: cold_cup_names)
cold_lids = Product.where(name: cold_lid_names, product_type: [ nil, 'standard' ])

cold_cups.each do |cup|
  type_label = cup.product_type == 'customizable_template' ? ' (branded)' : ''
  puts "\nProcessing cup: #{cup.name}#{type_label}"

  cold_lids.each_with_index do |lid, index|
    compatibility = ProductCompatibleLid.create!(
      product: cup,
      compatible_lid: lid,
      sort_order: index,
      default: index == 0 # First lid is default
    )
    puts "  ✓ Added compatible lid: #{lid.name} (default: #{compatibility.default})"
  end
end

# Summary
total_relationships = ProductCompatibleLid.count
cups_with_lids = Product.joins(:product_compatible_lids).distinct.count

puts "\n" + "=" * 60
puts "Lid compatibility population complete!"
puts "=" * 60
puts "Total relationships created: #{total_relationships}"
puts "Cups with compatible lids: #{cups_with_lids}"
