# frozen_string_literal: true

namespace :branded_products do
  desc "List all branded products with pricing information"
  task list: :environment do
    puts "Branded Products Report"
    puts "=" * 100
    puts ""

    # Find branded/customizable template products
    branded_products = Product.where(product_type: "customizable_template").order(:position)

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
      if product.description.present?
        puts ""
        puts "   Description: #{product.description[0..100]}#{'...' if product.description.length > 100}"
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

    unless product.product_type == "customizable_template"
      puts "⚠️  Product '#{product.name}' is not a branded/customizable product"
      puts "   Product type: #{product.product_type}"
      exit 1
    end

    puts "Branded Product: #{product.name}"
    puts "=" * 100
    puts "Slug: #{product.slug}"
    puts "Active: #{product.active ? 'Yes' : 'No'}"
    puts "Description: #{product.description}"
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

  desc "Import branded products and pricing data"
  task import: :environment do
    puts "Importing branded products..."
    load Rails.root.join("db/seeds/branded_product_pricing.rb")
  end
end
