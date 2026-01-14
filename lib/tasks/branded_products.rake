# frozen_string_literal: true

namespace :branded_products do
  desc "List all branded products with pricing information"
  task list: :environment do
    puts "Branded Products Report"
    puts "=" * 100
    puts ""

    # Find branded/customizable template products
    branded_products = Product.branded.order(:position)

    if branded_products.empty?
      puts "❌ No branded products found"
      puts "💡 Run 'rails branded_products:import' to import branded products and pricing"
      exit 0
    end

    puts "Total Branded Products: #{branded_products.count}"
    puts ""

    branded_products.each do |product|
      puts "📦 #{product.name}"
      puts "   Slug: #{product.slug}"
      puts "   Active: #{product.active ? '✅ Yes' : '❌ No'}"
      puts "   Position: #{product.position}"

      # Check for pricing data
      pricing_count = product.branded_product_prices.count
      if pricing_count > 0
        puts "   Pricing Tiers: #{pricing_count}"

        # Group pricing by size
        pricing_by_size = product.branded_product_prices.group_by(&:size)

        pricing_by_size.each do |size, prices|
          puts ""
          puts "   Size: #{size}"
          puts "   " + "-" * 80
          puts "   #{'Quantity'.ljust(15)} #{'Price/Unit'.ljust(15)} #{'Case Qty'.ljust(15)} Total Price"
          puts "   " + "-" * 80

          prices.sort_by(&:quantity_tier).each do |price|
            total = price.price_per_unit * price.quantity_tier
            puts "   #{price.quantity_tier.to_s.rjust(10)} units  " \
                 "£#{format('%.4f', price.price_per_unit).ljust(12)} " \
                 "#{price.case_quantity.to_s.ljust(12)} " \
                 "£#{format('%.2f', total)}"
          end
        end
      else
        puts "   Pricing: ⚠️  No pricing data (contact for quote)"
      end

      # Check description
      if product.description_standard_with_fallback.present?
        puts ""
        desc = product.description_standard_with_fallback
        puts "   Description: #{desc[0..100]}#{'...' if desc.length > 100}"
      end

      puts ""
      puts "-" * 100
      puts ""
    end

    # Summary statistics
    puts "=" * 100
    puts "Summary Statistics"
    puts "=" * 100
    puts "Total Products: #{branded_products.count}"
    puts "With Pricing: #{branded_products.count { |p| p.branded_product_prices.any? }}"
    puts "Without Pricing: #{branded_products.count { |p| p.branded_product_prices.empty? }}"
    puts "Active Products: #{branded_products.where(active: true).count}"
    puts "Total Pricing Entries: #{BrandedProductPrice.count}"
  end

  desc "Show pricing matrix for a specific branded product"
  task :show, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug
      puts "Usage: rails branded_products:show[product-slug]"
      puts "Example: rails branded_products:show[double-wall-branded-cups]"
      exit 1
    end

    product = Product.find_by(slug: slug)

    unless product
      puts "❌ Product not found: #{slug}"
      exit 1
    end

    unless product.customizable_template?
      puts "⚠️  Product '#{product.name}' is not a branded/customizable product"
      puts "   Product type: #{product.product_type}"
      exit 1
    end

    puts "Branded Product: #{product.name}"
    puts "=" * 100
    puts "Slug: #{product.slug}"
    puts "Active: #{product.active ? 'Yes' : 'No'}"
    puts "Description: #{product.description_standard_with_fallback}" if product.description_standard_with_fallback.present?
    puts ""

    prices = product.branded_product_prices.order(:size, :quantity_tier)

    if prices.empty?
      puts "❌ No pricing data available for this product"
      puts "💡 Contact for custom quote"
      exit 0
    end

    # Group by size
    pricing_by_size = prices.group_by(&:size)

    pricing_by_size.each do |size, size_prices|
      puts ""
      puts "Size: #{size}"
      puts "-" * 100
      printf "%-15s %-15s %-15s %-20s %-15s\n", "Quantity", "Price/Unit", "Case Qty", "Cases Needed", "Total Price"
      puts "-" * 100

      size_prices.each do |price|
        total = price.price_per_unit * price.quantity_tier
        cases = (price.quantity_tier.to_f / price.case_quantity).ceil

        printf "%-15s %-15s %-15s %-20s %-15s\n",
               "#{price.quantity_tier.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units",
               "£#{format('%.4f', price.price_per_unit)}",
               price.case_quantity,
               "#{cases} #{cases == 1 ? 'case' : 'cases'}",
               "£#{format('%.2f', total)}"
      end
    end

    puts ""
    puts "=" * 100
  end

  desc "List available sizes for branded products"
  task sizes: :environment do
    puts "Available Sizes for Branded Products"
    puts "=" * 80

    sizes = BrandedProductPrice.distinct.pluck(:size).sort

    if sizes.empty?
      puts "No sizes found"
    else
      sizes.each do |size|
        product_count = BrandedProductPrice.where(size: size).select(:product_id).distinct.count
        tier_count = BrandedProductPrice.where(size: size).count

        puts "  #{size.ljust(10)} - #{product_count} #{product_count == 1 ? 'product' : 'products'}, #{tier_count} pricing #{tier_count == 1 ? 'tier' : 'tiers'}"
      end
    end
  end

  desc "Import branded products and pricing data from CSV"
  task import: :environment do
    require "csv"

    puts "Importing branded products from CSV..."

    csv_path = Rails.root.join("lib/data/branded-cups.csv")
    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    # Find branded category
    branded_category = Category.find_by(slug: "branded-products")
    unless branded_category
      puts "ERROR: Branded Products category not found"
      puts "💡 Create a category with slug 'branded-products' first"
      exit 1
    end

    # Parse CSV (normalized format: one row per price point)
    csv = CSV.read(csv_path, headers: true)

    # Group by product name
    products_data = csv.group_by { |row| row["name"] }

    total_products = 0
    total_pricing = 0

    products_data.each do |name, rows|
      slug = name.parameterize
      sku = rows.first["sku"]
      case_qty = rows.first["pack_size"].to_i
      min_qty = rows.map { |r| r["quantity"].to_i }.min

      # Find or create product
      product = Product.find_or_create_by!(
        slug: slug,
        product_type: "customizable_template"
      ) do |p|
        p.name = name
        p.sku = sku
        p.price = 0.01
        p.category = branded_category
        p.description_short = "Custom branded #{name.downcase} with your design. Minimum order: #{min_qty.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units"
        p.description_standard = "Custom branded #{name.downcase} with your design. Minimum order: #{min_qty.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} units"
        p.description_detailed = "Custom branded #{name.downcase} with your design. Perfect for cafes, restaurants, and businesses looking to make an impression."
        p.active = true
        p.stock_quantity = 0
      end

      total_products += 1

      # Attach product photo if available
      photos_dir = Rails.root.join("lib/data/branded/photos", slug)
      if photos_dir.exist?
        main_photo = photos_dir.join("main.webp")
        if main_photo.exist? && !product.product_photo.attached?
          product.product_photo.attach(
            io: File.open(main_photo),
            filename: "#{slug}-main.webp",
            content_type: "image/webp"
          )
          puts "    📷 Attached product photo"
        end

        lifestyle_photo = photos_dir.join("lifestyle.webp")
        if lifestyle_photo.exist? && !product.lifestyle_photo.attached?
          product.lifestyle_photo.attach(
            io: File.open(lifestyle_photo),
            filename: "#{slug}-lifestyle.webp",
            content_type: "image/webp"
          )
          puts "    📷 Attached lifestyle photo"
        end
      end

      # Create pricing from each row
      sizes = Set.new
      rows.each do |row|
        size = row["size"]
        quantity = row["quantity"].to_i
        price = row["price_per_unit"].to_f

        sizes << size

        product.branded_product_prices.find_or_create_by!(
          size: size,
          quantity_tier: quantity
        ) do |bp|
          bp.price_per_unit = price
          bp.case_quantity = case_qty
        end
        total_pricing += 1
      end

      puts "  ✓ #{name}: #{sizes.size} sizes, #{rows.size} pricing tiers (case qty: #{case_qty})"
    end

    puts ""
    puts "Branded product import complete!"
    puts "  Total products: #{total_products}"
    puts "  Total pricing entries: #{total_pricing}"

    # Populate lid compatibility
    puts ""
    puts "Populating lid compatibility..."
    Rake::Task["lid_compatibility:populate"].invoke
  end
end
