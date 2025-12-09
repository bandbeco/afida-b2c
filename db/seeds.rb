# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require 'csv'

puts "Loading categories metadata from CSV..."
categories_metadata = {}
CSV.foreach(Rails.root.join('lib', 'data', 'categories.csv'), headers: true) do |row|
  data = row.to_h
  slug = data['slug']&.strip
  if slug
    categories_metadata[slug] = {
      name: data['name']&.strip&.gsub(/\s+/, ' '),
      meta_title: data['meta_title']&.strip,
      meta_description: data['meta_description']&.strip&.gsub(/\s+/, ' '),
      description: data['description']&.strip
    }
  end
end
puts "Categories metadata loaded."

# Create categories from the metadata loaded from CSV
puts "Creating categories..."
categories_metadata.each do |slug, metadata|
  category = Category.find_or_initialize_by(slug: slug)
  category.name = metadata[:name]
  category.meta_title = metadata[:meta_title]
  category.meta_description = metadata[:meta_description]
  category.description = metadata[:description]
  category.save!
  puts "  Created/Updated category: #{metadata[:name]} (#{slug})"
end

# Keep branded products category for custom products
branded_category = Category.find_or_create_by!(
  name: "Branded Products",
  slug: "branded-products",
  meta_title: "Branded Products - Custom Packaging | Afida",
  meta_description: "Custom branded packaging for your business."
)
puts "  Created/Updated category: Branded Products (branded-products)"

# Load product options first (required for products with options)
load Rails.root.join('db', 'seeds', 'product_options.rb')

# Load products from consolidated CSV (replaces YAML-based seeding)
load Rails.root.join('db', 'seeds', 'products_from_csv.rb')

# Load branded product pricing seed
load Rails.root.join('db', 'seeds', 'branded_product_pricing.rb')

# Load product photos (after products are created)
load Rails.root.join('db', 'seeds', 'product_photos.rb')

# Load URL redirect mappings
load Rails.root.join('db', 'seeds', 'url_redirects.rb')

puts "Seeding completed!"
puts "Categories created: #{Category.count}"
puts "Products created: #{Product.count}"
puts "Product variants created: #{ProductVariant.count}" if defined?(ProductVariant)
puts "Product options created: #{ProductOption.count}" if defined?(ProductOption)
puts "Product option values created: #{ProductOptionValue.count}" if defined?(ProductOptionValue)
puts "Branded product prices created: #{BrandedProductPrice.count}" if defined?(BrandedProductPrice)
puts "Products with photos: #{Product.joins(:product_photo_attachment).distinct.count}"
puts "Variants with photos: #{ProductVariant.joins(:product_photo_attachment).distinct.count}" if defined?(ProductVariant)
