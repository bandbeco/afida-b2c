require "csv"

namespace :products do
  desc "Backfill size column from CSV data"
  task backfill_size: :environment do
    csv_file = Rails.root.join("lib", "data", "products.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Loading size data from CSV..."

    # Build SKU → size mapping from CSV
    sku_to_size = {}
    CSV.foreach(csv_file, headers: true) do |row|
      sku = row["sku"]&.strip
      size_label = row["size_label"]&.strip

      next if sku.blank?
      sku_to_size[sku] = size_label if size_label.present?
    end

    puts "Found #{sku_to_size.size} SKUs with size data"

    # Update products
    updated = 0
    skipped = 0
    not_found = 0

    Product.find_each do |product|
      size = sku_to_size[product.sku]

      if size.present?
        product.update_column(:size, size)
        updated += 1
        puts "  ✓ #{product.sku}: #{size}"
      elsif product.size.blank?
        skipped += 1
      end
    end

    # Report SKUs in CSV but not in database
    db_skus = Product.pluck(:sku)
    missing = sku_to_size.keys - db_skus
    if missing.any?
      puts "\nSKUs in CSV but not in database: #{missing.count}"
    end

    puts "\n" + "=" * 50
    puts "Backfill completed!"
    puts "Updated: #{updated}"
    puts "Skipped (no size in CSV): #{skipped}"
    puts "=" * 50
  end
end
