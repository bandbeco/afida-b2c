# Seed products from final consolidated CSV with BrandYour categories
require 'csv'

puts 'Loading products from CSV...'

csv_path = Rails.root.join('lib', 'data', 'products.csv')

unless File.exist?(csv_path)
  puts "ERROR: CSV file not found at #{csv_path}"
  return
end

# Get existing options
size_option = ProductOption.find_by(name: 'size')
color_option = ProductOption.find_by(name: 'colour')
material_option = ProductOption.find_by(name: 'material')
type_option = ProductOption.find_by(name: 'type')

# Group CSV rows by product
products_data = {}

CSV.foreach(csv_path, headers: true) do |row|
  product_name = row['product']
  category_slug = row['category_slug']

  key = "#{product_name}|#{category_slug}"

  products_data[key] ||= {
    name: product_name,
    category_slug: category_slug,
    slug: row['slug'],
    material: row['material'],
    meta_title: row['meta_title'],
    meta_description: row['meta_description'],
    description_short: row['description_short'],
    description_standard: row['description_standard'],
    description_detailed: row['description_detailed'],
    material: row['material'],
    variants: []
  }

  products_data[key][:variants] << {
    type: row['type_value'],
    type_label: row['type_label'],
    size: row['size_value'],
    size_label: row['size_label'],
    colour: row['colour_value'],
    colour_label: row['colour_label'],
    material: row['material_value'],
    material_label: row['material_label'],
    sku: row['sku'],
    price: row['price']&.gsub('£', '')&.gsub(',', '')&.to_f || 0,
    pac_size: row['pac_size']&.to_i || 1,
    sample_eligible: row['sample_eligible']&.downcase == 'true',
    active: row['active']&.downcase == 'true'
  }
end

puts "Found #{products_data.length} unique products"

# Create products and variants
products_data.each do |key, data|
  category = Category.find_by(slug: data[:category_slug])

  unless category
    puts "  ⚠ Skipping #{data[:name]} - category '#{data[:category_slug]}' not found"
    next
  end

  # Create or update product
  product = Product.find_or_initialize_by(slug: data[:slug])
  product.name = data[:name]
  product.category = category
  product.meta_title = data[:meta_title]
  product.meta_description = data[:meta_description]
  product.description_short = data[:description_short]
  product.description_standard = data[:description_standard]
  product.description_detailed = data[:description_detailed]
  product.material = data[:material]
  product.active = true
  product.product_type = 'standard'
  product.save!

  # Determine which options to assign
  types = data[:variants].map { |v| v[:type] }.compact.uniq
  sizes = data[:variants].map { |v| v[:size] }.compact.uniq
  colours = data[:variants].map { |v| v[:colour] }.compact.uniq
  materials = data[:variants].map { |v| v[:material] }.compact.uniq

  has_type_variants = types.length > 1
  has_size_variants = sizes.length > 1
  has_color_variants = colours.length > 1
  has_material_variants = materials.length > 1

  # Assign Size option if product has multiple sizes
  if has_size_variants && size_option
    product.option_assignments.find_or_create_by!(product_option: size_option) do |a|
      a.position = 1
    end
  end

  # Assign Color option if product has multiple colors
  if has_color_variants && color_option
    product.option_assignments.find_or_create_by!(product_option: color_option) do |a|
      a.position = 2
    end
  end

  # Assign Material option if product has multiple materials
  if has_material_variants && material_option
    product.option_assignments.find_or_create_by!(product_option: material_option) do |a|
      a.position = 3
    end
  end

  # Assign Type option if product has multiple types
  if has_type_variants && type_option
    product.option_assignments.find_or_create_by!(product_option: type_option) do |a|
      a.position = 4
    end
  end

  # Create variants
  data[:variants].each do |variant_data|
    # Build option values hash for name generation (includes labels from CSV)
    option_values_hash = {}
    if variant_data[:type].present?
      option_values_hash['type'] = { value: variant_data[:type], label: variant_data[:type_label] }
    end
    if variant_data[:size].present?
      option_values_hash['size'] = { value: variant_data[:size], label: variant_data[:size_label] }
    end
    if variant_data[:colour].present?
      option_values_hash['colour'] = { value: variant_data[:colour], label: variant_data[:colour_label] }
    end
    if variant_data[:material].present?
      option_values_hash['material'] = { value: variant_data[:material], label: variant_data[:material_label] }
    end

    # Create variant name from options that actually vary
    # Only include option if product has multiple values for that option
    variant_name_parts = []
    variant_name_parts << variant_data[:type] if has_type_variants && variant_data[:type].present?
    variant_name_parts << variant_data[:material] if has_material_variants && variant_data[:material].present?
    variant_name_parts << variant_data[:size] if has_size_variants && variant_data[:size].present?
    variant_name_parts << variant_data[:colour] if has_color_variants && variant_data[:colour].present?
    variant_name = variant_name_parts.join(' ')
    variant_name = 'Standard' if variant_name.blank?

    variant = product.variants.find_or_initialize_by(sku: variant_data[:sku])
    variant.name = variant_name
    variant.price = variant_data[:price]
    variant.pac_size = variant_data[:pac_size]
    variant.stock_quantity = 10000
    variant.active = variant_data[:active]
    variant.sample_eligible = true  # All variants are sample eligible
    variant.save!

    # Create variant_option_values join records (new normalized structure)
    # Link variant to ProductOptionValue records via join table
    option_values_hash.each do |option_name, option_data|
      next if option_data.blank? || option_data[:value].blank?

      # Find the ProductOption (size, colour, material, type)
      product_option = ProductOption.find_by(name: option_name)
      next unless product_option

      # Find or create the ProductOptionValue with label from CSV
      product_option_value = product_option.values.find_or_initialize_by(value: option_data[:value])
      # Set/update the label if provided in CSV
      if option_data[:label].present?
        product_option_value.label = option_data[:label]
      end
      product_option_value.save!

      # Create the join record (skip if exists)
      variant.variant_option_values.find_or_create_by!(
        product_option_value: product_option_value,
        product_option: product_option
      )
    end
  end

  # Set product active if it has any active variants
  active_variant_count = product.variants.where(active: true).count
  product.update!(active: active_variant_count > 0)

  status = product.active ? '✓' : '○'
  puts "  #{status} #{product.name} (#{active_variant_count}/#{product.variants.count} active variants)"
end

puts ''
puts 'Products seeded successfully!'
puts "  Total products: #{Product.standard.count}"
puts "  Total variants: #{ProductVariant.count}"
puts "  Products with Size option: #{ProductOptionAssignment.where(product_option: size_option).count}"
puts "  Products with Colour option: #{ProductOptionAssignment.where(product_option: color_option).count}"
puts "  Products with Material option: #{ProductOptionAssignment.where(product_option: material_option).count}"
puts "  Products with Type option: #{ProductOptionAssignment.where(product_option: type_option).count}"
