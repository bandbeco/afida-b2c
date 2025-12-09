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
    variants: []
  }

  products_data[key][:variants] << {
    size: row['size_value'],
    colour: row['colour_value'],
    sku: row['sku'],
    price: row['price']&.gsub('£', '')&.gsub(',', '')&.to_f || 0,
    pac_size: row['pac_size']&.to_i || 1
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
  sizes = data[:variants].map { |v| v[:size] }.compact.uniq
  colours = data[:variants].map { |v| v[:colour] }.uniq

  has_size_variants = sizes.length > 1
  has_color_variants = colours.length > 1

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

  # Create variants
  data[:variants].each do |variant_data|
    option_values = {}
    option_values['size'] = variant_data[:size] if variant_data[:size].present?
    option_values['colour'] = variant_data[:colour] if variant_data[:colour].present?

    # Create variant name from options that actually vary
    # Only include size if product has multiple sizes
    # Only include colour if product has multiple colours
    variant_name_parts = []
    variant_name_parts << variant_data[:size] if has_size_variants && variant_data[:size].present?
    variant_name_parts << variant_data[:colour] if has_color_variants && variant_data[:colour].present?
    variant_name = variant_name_parts.join(' ')
    variant_name = 'Standard' if variant_name.blank?

    variant = product.variants.find_or_initialize_by(sku: variant_data[:sku])
    variant.name = variant_name
    variant.price = variant_data[:price]
    variant.pac_size = variant_data[:pac_size]
    variant.stock_quantity = 10000
    variant.option_values = option_values
    variant.active = true
    variant.save!
  end

  puts "  ✓ #{product.name} (#{product.variants.count} variants)"
end

puts ''
puts 'Products seeded successfully!'
puts "  Total products: #{Product.standard.count}"
puts "  Total variants: #{ProductVariant.count}"
puts "  Products with Size option: #{ProductOptionAssignment.where(product_option: size_option).count}"
puts "  Products with Colour option: #{ProductOptionAssignment.where(product_option: color_option).count}"
