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
categories_csv = CSV.read(Rails.root.join('lib', 'data', 'categories.csv'), headers: true)

# Without this column every row looks top-level, which would silently flatten
# the taxonomy and break every /categories/:parent_slug/:id URL.
unless categories_csv.headers.include?('parent_slug')
  raise "categories.csv is missing the parent_slug column — refusing to seed a flattened taxonomy"
end

category_rows = categories_csv.map(&:to_h).reject { |row| row['slug'].to_s.strip.blank? }
puts "Categories metadata loaded."

upsert_category = lambda do |row, parent|
  category = Category.find_or_initialize_by(slug: row['slug'].strip)
  category.name = row['name']&.strip&.gsub(/\s+/, ' ')
  category.parent = parent
  # Only assign copy the CSV actually carries. A blank cell means "no opinion",
  # not "clear it": most rows ship blank and rely on the model's
  # meta_*_with_fallback, and production holds copy this file does not.
  category.meta_title = row['meta_title'].strip if row['meta_title'].present?
  category.meta_description = row['meta_description'].strip.gsub(/\s+/, ' ') if row['meta_description'].present?
  category.description = row['description'].strip if row['description'].present?
  category.save!
  puts "  Created/Updated category: #{category.name} (#{category.slug})"
  category
end

# Two passes: the taxonomy is nested (parent + subcategory), so a child cannot
# be saved before its parent row exists. Rows with a blank parent_slug are the
# top-level parents. See test/data/seed_data_test.rb for the shape this expects.
puts "Creating categories..."
parents = category_rows.select { |row| row['parent_slug'].blank? }.to_h do |row|
  [ row['slug'].strip, upsert_category.call(row, nil) ]
end

category_rows.reject { |row| row['parent_slug'].blank? }.each do |row|
  parent = parents.fetch(row['parent_slug'].strip) do
    raise "categories.csv: #{row['slug']} names unknown parent #{row['parent_slug'].inspect}"
  end
  upsert_category.call(row, parent)
end

# Keep branded products category for custom products
branded_category = Category.find_or_create_by!(
  name: "Branded Products",
  slug: "branded-products",
  meta_title: "Branded Products - Custom Packaging | Afida",
  meta_description: "Custom branded packaging for your business."
)
puts "  Created/Updated category: Branded Products (branded-products)"

# Seeding never deletes. A database seeded before the June 2026 restructure
# still holds the old flat categories, which are no longer in the CSV: they
# survive as empty top-level rows and, because they sort first, head the nav
# and footer while linking to paths config/routes.rb 301s away.
seeded_slugs = category_rows.map { |row| row['slug'].strip } + [ branded_category.slug ]
stale_categories = Category.where.not(slug: seeded_slugs).order(:parent_id, :position)

if stale_categories.any?
  puts ""
  puts "  WARNING: #{stale_categories.count} categor#{stale_categories.count == 1 ? 'y is' : 'ies are'} in the database but not in categories.csv."
  puts "  These predate the current taxonomy. Top-level ones sort ahead of the real"
  puts "  parents in the nav and footer. Review and remove them, or re-seed from scratch:"
  stale_categories.each do |category|
    location = category.parent_id ? "child of #{category.parent&.slug}" : "TOP-LEVEL"
    puts "    - #{category.slug} (#{location}, #{category.products.count} products)"
  end
  puts ""
end

# Load products from consolidated CSV
load Rails.root.join('db', 'seeds', 'products_from_csv.rb')

# Load branded product pricing seed
load Rails.root.join('db', 'seeds', 'branded_product_pricing.rb')

# Lid compatibility is admin-curated production data (product_compatible_lids);
# it is deliberately not seeded so reseeding can never wipe the curated rows.

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

# UK bank holidays for the delivery promise. Populated from GOV.UK so a fresh
# deploy isn't cold-empty; the daily RefreshBankHolidaysJob keeps it current.
puts ""
puts "Loading UK bank holidays..."
dates = BankHolidaysFetcher.fetch
if dates
  BankHoliday.replace_division(BankHolidaysFetcher::DIVISION, dates)
  puts "  Loaded #{dates.size} bank holidays for #{BankHolidaysFetcher::DIVISION}"
else
  puts "  Could not fetch bank holidays (will retry via RefreshBankHolidaysJob)"
end
