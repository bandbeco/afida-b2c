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
    name_updated_count = 0

    # Group products by their variant SKUs to find duplicates
    # Products with identical variant sets are duplicates
    product_groups = Product.includes(:variants).all.group_by do |product|
      product.variants.pluck(:sku).sort.join(",")
    end

    product_groups.each do |variant_skus, products|
      next if products.count == 1 # No duplicates
      next if variant_skus.blank? # Skip products with no variants

      puts ""
      puts "Found duplicate products with variants: #{variant_skus}"

      # Find the product with photos (the one we want to keep)
      product_with_photos = products.find { |p| p.product_photo.attached? || p.lifestyle_photo.attached? }
      product_with_photos ||= products.find { |p| p.variants.any? { |v| v.product_photo.attached? || v.lifestyle_photo.attached? } }

      # If still no product with photos, keep the oldest one
      product_with_photos ||= products.min_by(&:created_at)

      # Get the first variant SKU to look up in CSV
      first_variant_sku = product_with_photos.variants.first&.sku
      csv_row = CSV.foreach(csv_path, headers: true).find { |row| row["sku"] == first_variant_sku }

      if csv_row
        new_slug = csv_row["slug"]
        new_name = csv_row["product"]

        # Delete duplicates (products without photos)
        products_to_delete = products - [ product_with_photos ]

        products_to_delete.each do |product|
          puts "  🗑  Deleting duplicate: #{product.name} (#{product.slug}) - no photos"
          product.destroy
          deleted_count += 1
        end

        # Update the keeper's slug and name if needed
        updates = {}
        updates[:slug] = new_slug if product_with_photos.slug != new_slug
        updates[:name] = new_name if product_with_photos.name != new_name

        if updates.any?
          old_slug = product_with_photos.slug
          old_name = product_with_photos.name
          product_with_photos.update!(updates)

          if updates[:slug]
            puts "  ✓ Updated slug: #{old_name} (#{old_slug} → #{new_slug})"
            updated_count += 1
          end

          if updates[:name]
            puts "  ✓ Updated name: #{old_name} → #{new_name}"
            name_updated_count += 1
          end
        else
          puts "  → Already correct: #{product_with_photos.name} (#{product_with_photos.slug})"
        end
      else
        puts "  ⚠ No CSV row found for variant SKU: #{first_variant_sku}"
      end
    end

    puts ""
    puts "Done!"
    puts "  Slugs updated: #{updated_count}"
    puts "  Names updated: #{name_updated_count}"
    puts "  Duplicates deleted: #{deleted_count}"
    puts "  Total products now: #{Product.count}"
  end
end
