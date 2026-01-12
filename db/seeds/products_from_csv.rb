# Seed products from consolidated CSV
# Each CSV row becomes a Product (the main sellable entity)
# Products with the same name are grouped under a ProductFamily

require 'csv'

puts 'Loading products from CSV...'

csv_path = Rails.root.join('lib', 'data', 'products.csv')

unless File.exist?(csv_path)
  puts "ERROR: CSV file not found at #{csv_path}"
  return
end

# Track product families by name for grouping
product_families = {}

# Track products created and slugs for uniqueness validation
products_created = 0
products_updated = 0
slugs_seen = {}

# Helper to generate SEO-friendly slug from product attributes
# Format: {name}-{size}-{colour}-{material}
# Deduplicates identical values (e.g., colour="Kraft", material="Kraft" -> single "kraft")
def generate_seo_slug(row)
  parts = []

  # Product name (e.g., "Cocktail Napkins", "Hot Cups")
  parts << row['product_name']

  # Size (e.g., "40x40cm", "12oz")
  size = row['size_label'].presence || row['size_value'].presence
  parts << size if size.present?

  # Colour (e.g., "Black", "White")
  colour = row['colour_label'].presence || row['colour_value'].presence
  parts << colour if colour.present?

  # Material (e.g., "Airlaid", "Paper") - helps differentiate similar products
  material = row['material_label'].presence || row['material_value'].presence
  parts << material if material.present?

  # Join, deduplicate (case-insensitive), and parameterize
  parts.map(&:to_s).map(&:strip).reject(&:blank?).uniq(&:downcase).join(' ').parameterize
end

CSV.foreach(csv_path, headers: true) do |row|
  product_family_name = row['product_family']
  product_name = row['product_name']
  category_slug = row['category_slug']

  category = Category.find_by(slug: category_slug)
  unless category
    puts "  ⚠ Skipping #{row['sku']} - category '#{category_slug}' not found"
    next
  end

  # Generate SEO-friendly slug from attributes
  slug = generate_seo_slug(row)

  # Validate slug uniqueness - fail if duplicate
  if slugs_seen[slug]
    raise "Duplicate slug '#{slug}' generated for SKU #{row['sku']} (conflicts with SKU #{slugs_seen[slug]})"
  end
  slugs_seen[slug] = row['sku']

  # Create or find ProductFamily for grouping products with the same family name
  family_key = "#{product_family_name}|#{category_slug}"
  unless product_families[family_key]
    family_slug = product_family_name.to_s.parameterize
    family = ProductFamily.find_or_create_by!(slug: family_slug) do |f|
      f.name = product_family_name
    end
    product_families[family_key] = family
  end
  product_family = product_families[family_key]

  # Parse price - remove currency symbol and commas
  price = row['price']&.gsub('£', '')&.gsub(',', '')&.to_f || 0

  # Create or update product by SKU (unique identifier)
  product = Product.find_or_initialize_by(sku: row['sku'])
  is_new = product.new_record?

  product.assign_attributes(
    name: product_name,
    slug: slug,
    category: category,
    product_family: product_family,
    price: price,
    pac_size: row['pac_size']&.to_i || 1,
    stock_quantity: 10000,
    active: row['active']&.downcase == 'true',
    sample_eligible: row['sample_eligible']&.downcase == 'true',
    product_type: 'standard',
    # SEO and descriptions
    meta_title: row['meta_title'],
    meta_description: row['meta_description'],
    description_short: row['description_short'],
    description_standard: row['description_standard'],
    description_detailed: row['description_detailed'],
    # Product attributes
    material: row['material_label'].presence || row['material_value'],
    colour: row['colour_label'].presence || row['colour_value'],
    size: row['size_label'].presence || row['size_value']
  )

  product.save!

  if is_new
    products_created += 1
  else
    products_updated += 1
  end

  status = product.active ? '✓' : '○'
  puts "  #{status} #{product.name} (#{product.sku})"
end

puts ''
puts 'Products seeded successfully!'
puts "  Products created: #{products_created}"
puts "  Products updated: #{products_updated}"
puts "  Total products: #{Product.standard.count}"
puts "  Product families: #{ProductFamily.count}"
