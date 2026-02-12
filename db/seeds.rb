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

# Load products from consolidated CSV
load Rails.root.join('db', 'seeds', 'products_from_csv.rb')

# Load branded product pricing seed (must run before lid_compatibility)
load Rails.root.join('db', 'seeds', 'branded_product_pricing.rb')

# Populate lid compatibility relationships (cups → lids)
# Runs after branded products exist so they get lid compatibility too
load Rails.root.join('db', 'seeds', 'lid_compatibility.rb')

# Load branded product photos (after branded products are created)
load Rails.root.join('db', 'seeds', 'branded_product_photos.rb')

# Load product photos (after products are created)
load Rails.root.join('db', 'seeds', 'product_photos.rb')

# Load URL redirect mappings
load Rails.root.join('db', 'seeds', 'url_redirects.rb')

# Load site settings and branding images
load Rails.root.join('db', 'seeds', 'site_settings.rb')

# Mark 8 random products as featured
puts "Marking featured products..."
Product.update_all(featured: false)
Product.standard.order("RANDOM()").limit(8).update_all(featured: true)
puts "  Marked #{Product.where(featured: true).count} products as featured"

puts "Seeding completed!"
puts "Categories created: #{Category.count}"
puts "Products created: #{Product.count}"
puts "Product families created: #{ProductFamily.count}" if defined?(ProductFamily)
puts "Branded product prices created: #{BrandedProductPrice.count}" if defined?(BrandedProductPrice)
puts "Lid compatibility relationships: #{ProductCompatibleLid.count}" if defined?(ProductCompatibleLid)
puts "Products with photos: #{Product.joins(:product_photo_attachment).distinct.count}"

# Report products without photos
products_without_photos = Product
  .active
  .where.not(id: Product.joins(:product_photo_attachment).select(:id))
  .where.not("sku LIKE 'P-%'")
  .where(product_type: [ nil, "standard" ])
  .order(:name, :sku)

if products_without_photos.any?
  puts ""
  puts "Products without photos (#{products_without_photos.count}):"
  products_without_photos.each do |product|
    puts "  - #{product.generated_title}: #{product.sku}"
  end
end
