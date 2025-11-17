require "csv"

namespace :products do
  desc "Update product slugs to pluralized versions and remove duplicates"
  task fix_slugs: :environment do
    puts "Fixing product slugs..."

    # Load CSV to get the current (pluralized) slugs
    csv_path = Rails.root.join("lib", "data", "products.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    # Build mapping of product names to their new slugs
    product_slug_mapping = {}

    CSV.foreach(csv_path, headers: true) do |row|
      product_name = row["product"]
      slug = row["slug"]
      product_slug_mapping[product_name] = slug
    end

    puts "Found #{product_slug_mapping.keys.uniq.count} unique products in CSV"
    puts ""

    updated_count = 0
    deleted_count = 0

    # Group products by name to find duplicates
    Product.all.group_by(&:name).each do |name, products|
      next if products.count == 1 # No duplicates

      # We have duplicates
      new_slug = product_slug_mapping[name]

      unless new_slug
        puts "  ⚠ No slug found in CSV for: #{name}"
        next
      end

      # Find the product with photos (the one we want to keep)
      product_with_photos = products.find { |p| p.product_photo.attached? || p.lifestyle_photo.attached? }
      product_with_photos ||= products.find { |p| p.variants.any? { |v| v.product_photo.attached? || v.lifestyle_photo.attached? } }

      # If still no product with photos, keep the oldest one
      product_with_photos ||= products.min_by(&:created_at)

      # Delete duplicates (products without photos)
      products_to_delete = products - [ product_with_photos ]

      products_to_delete.each do |product|
        puts "  🗑  Deleting duplicate: #{product.name} (#{product.slug}) - no photos"
        product.destroy
        deleted_count += 1
      end

      # Update the keeper's slug if needed
      if product_with_photos.slug != new_slug
        old_slug = product_with_photos.slug
        product_with_photos.update!(slug: new_slug)
        puts "  ✓ Updated: #{product_with_photos.name} (#{old_slug} → #{new_slug})"
        updated_count += 1
      else
        puts "  → Already correct: #{product_with_photos.name} (#{product_with_photos.slug})"
      end
    end

    puts ""
    puts "Done!"
    puts "  Products updated: #{updated_count}"
    puts "  Duplicates deleted: #{deleted_count}"
    puts "  Total products now: #{Product.count}"
  end
end
