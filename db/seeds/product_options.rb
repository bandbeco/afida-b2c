# Product Options (reusable across products)
puts "Creating product options..."

# Size Option
size_option = ProductOption.find_or_create_by!(name: "size") do |option|
  option.display_type = "dropdown"
  option.required = true
  option.position = 1
end

[ "8oz", "12oz", "16oz", "20oz" ].each_with_index do |size, index|
  size_option.values.find_or_create_by!(value: size) do |v|
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
puts "  - Size: 4 values (8oz, 12oz, 16oz, 20oz)"
puts "  - Color: 3 values (White, Black, Kraft)"
puts "  - Material: 3 values (Recyclable, Compostable, Biodegradable)"
