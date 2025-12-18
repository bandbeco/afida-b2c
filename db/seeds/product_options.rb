# Product Options (reusable across products)
puts "Creating product options..."

# Size Option
size_option = ProductOption.find_or_create_by!(name: "size") do |option|
  option.display_type = "dropdown"
  option.required = true
  option.position = 1
end

# All size values with human-readable labels
# Format: [value, label] - label is used for display in UI
SIZE_VALUES = [
  # Cup sizes
  [ "4oz", "4oz" ],
  [ "5oz", "5oz" ],
  [ "6oz", "6oz" ],
  [ "8oz", "8oz" ],
  [ "9oz", "9oz" ],
  [ "10oz", "10oz" ],
  [ "12oz", "12oz" ],
  [ "16oz", "16oz" ],
  [ "20oz", "20oz" ],
  # Pizza box sizes (inches)
  [ "7in", "7 inch" ],
  [ "9in", "9 inch" ],
  [ "12in", "12 inch" ],
  [ "16in", "16 inch" ],
  # Napkin sizes
  [ "33x33cm", "33cm x 33cm" ],
  # Straw sizes
  [ "6x140mm", "6mm x 140mm" ],
  [ "6x150mm", "6mm x 150mm" ],
  [ "6x200mm", "6mm x 200mm" ],
  [ "8x200mm", "8mm x 200mm" ],
  [ "10x200mm", "10mm x 200mm" ],
  # Lid diameters
  [ "140mm", "140mm diameter" ],
  [ "180mm", "180mm diameter" ],
  # Food container sizes
  [ "no1-755ml", "No.1 (755ml)" ],
  [ "no3-1900ml", "No.3 (1900ml)" ],
  [ "no8-1300ml", "No.8 (1300ml)" ],
  # Soup containers
  [ "500ml", "500ml" ],
  [ "750ml", "750ml" ],
  [ "1000ml", "1000ml" ],
  [ "500-1000ml", "500-1000ml" ],
  # Cup carriers
  [ "2-cup", "2 cup" ],
  [ "4-cup", "4 cup" ],
  # General sizes
  [ "small", "Small" ],
  [ "medium", "Medium" ],
  [ "large", "Large" ],
  [ "half-pint", "Half Pint" ],
  [ "pint", "Pint" ],
  # Lid compatibility
  [ "8-12oz", "8-12oz" ],
  [ "9oz-compatible", "9oz compatible" ],
  [ "12oz-compatible", "12oz compatible" ],
  [ "16-20oz-compatible", "16-20oz compatible" ],
  [ "16-20oz ", "16-20oz" ]
].freeze

SIZE_VALUES.each_with_index do |(value, label), index|
  size_option.values.find_or_create_by!(value: value) do |v|
    v.label = label
    v.position = index + 1
  end
end

# Color Option
color_option = ProductOption.find_or_create_by!(name: "colour") do |option|
  option.display_type = "swatch"
  option.required = true
  option.position = 2
end

[ "White", "Black", "Kraft" ].each_with_index do |color, index|
  color_option.values.find_or_create_by!(value: color) do |v|
    v.position = index + 1
  end
end

# Material Option
material_option = ProductOption.find_or_create_by!(name: "material") do |option|
  option.display_type = "radio"
  option.required = false
  option.position = 3
end

[ "Recyclable", "Compostable", "Biodegradable" ].each_with_index do |material, index|
  material_option.values.find_or_create_by!(value: material) do |v|
    v.position = index + 1
  end
end

puts "Product options created successfully!"
puts "  - Size: #{size_option.values.count} values (cups, pizza boxes, straws, containers, etc.)"
puts "  - Colour: #{color_option.values.count} values (White, Black, Kraft)"
puts "  - Material: #{material_option.values.count} values (Recyclable, Compostable, Biodegradable)"
