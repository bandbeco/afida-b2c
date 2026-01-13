require "csv"

namespace :seo do
  desc "Apply SEO optimizations to products from products_seo_updates.csv"
  task update_products: :environment do
    csv_file = Rails.root.join("lib", "data", "products_seo_updates.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Applying SEO updates from #{csv_file}..."

    stats = {
      updated: 0,
      not_found: 0,
      unchanged: 0,
      errors: []
    }

    CSV.foreach(csv_file, headers: true) do |row|
      slug = row["slug"]&.strip
      next if slug.blank?

      begin
        product = Product.find_by(slug: slug)

        if product.nil?
          stats[:not_found] += 1
          puts "  Not found: #{slug}"
          next
        end

        changes_made = false

        if row["meta_title"].present? && product.meta_title != row["meta_title"]
          product.meta_title = row["meta_title"]
          changes_made = true
        end

        if row["meta_description"].present? && product.meta_description != row["meta_description"]
          product.meta_description = row["meta_description"]
          changes_made = true
        end

        if changes_made
          product.save!
          stats[:updated] += 1
          puts "  Updated: #{product.name} (#{slug})"
        else
          stats[:unchanged] += 1
          puts "  Unchanged: #{slug}"
        end

      rescue => e
        error_msg = "Error updating #{slug}: #{e.message}"
        stats[:errors] << error_msg
        puts "  ERROR: #{error_msg}"
      end
    end

    puts "\n" + "=" * 60
    puts "SEO update completed!"
    puts "=" * 60
    puts "Products updated: #{stats[:updated]}"
    puts "Products unchanged: #{stats[:unchanged]}"
    puts "Products not found: #{stats[:not_found]}"

    if stats[:errors].any?
      puts "\nErrors (#{stats[:errors].count}):"
      stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts "=" * 60
  end

  desc "Validate SEO coverage for all products"
  task validate_products: :environment do
    puts "Validating product SEO coverage..."
    puts "=" * 60

    issues = []

    Product.find_each do |product|
      product_issues = []
      product_issues << "missing meta_title" if product.meta_title.blank?
      product_issues << "missing meta_description" if product.meta_description.blank?
      product_issues << "meta_title too long (#{product.meta_title.length} chars)" if product.meta_title.present? && product.meta_title.length > 60
      product_issues << "meta_description too long (#{product.meta_description.length} chars)" if product.meta_description.present? && product.meta_description.length > 160

      if product_issues.any?
        issues << { product: product, issues: product_issues }
      end
    end

    if issues.any?
      puts "Found #{issues.count} products with SEO issues:\n"
      issues.each do |item|
        puts "  #{item[:product].name} (#{item[:product].slug}):"
        item[:issues].each { |issue| puts "    - #{issue}" }
      end
    else
      puts "All products have complete SEO data!"
    end

    puts "\n" + "=" * 60
    puts "Summary:"
    puts "  Total products: #{Product.count}"
    puts "  Products with issues: #{issues.count}"
    puts "  Products complete: #{Product.count - issues.count}"
    puts "=" * 60
  end

  desc "Import unique SEO content per product variant from product_seo_update.csv (by SKU)"
  task import_variant_seo: :environment do
    csv_file = Rails.root.join("lib", "data", "product_seo_update.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Importing variant-specific SEO content from #{csv_file}..."
    puts "=" * 60

    stats = { updated: 0, not_found: 0, unchanged: 0, errors: [] }

    CSV.foreach(csv_file, headers: true) do |row|
      sku = row["sku"]&.strip
      next if sku.blank?

      begin
        product = Product.find_by(sku: sku)

        if product.nil?
          stats[:not_found] += 1
          puts "  Not found: #{sku}"
          next
        end

        changes = []

        if row["meta_title"].present? && product.meta_title != row["meta_title"]
          product.meta_title = row["meta_title"]
          changes << "meta_title"
        end

        if row["meta_description"].present? && product.meta_description != row["meta_description"]
          product.meta_description = row["meta_description"]
          changes << "meta_description"
        end

        if changes.any?
          product.save!
          stats[:updated] += 1
          puts "  Updated: #{sku} (#{changes.join(', ')})"
        else
          stats[:unchanged] += 1
        end

      rescue => e
        error_msg = "#{sku}: #{e.message}"
        stats[:errors] << error_msg
        puts "  ERROR: #{error_msg}"
      end
    end

    puts "\n" + "=" * 60
    puts "Import completed!"
    puts "  Updated: #{stats[:updated]}"
    puts "  Unchanged: #{stats[:unchanged]}"
    puts "  Not found: #{stats[:not_found]}"
    puts "  Errors: #{stats[:errors].count}"
    stats[:errors].each { |e| puts "    - #{e}" } if stats[:errors].any?
    puts "=" * 60
  end

  desc "Generate SEO report for all products and categories"
  task report: :environment do
    puts "=" * 60
    puts "SEO Coverage Report"
    puts "=" * 60

    # Category stats
    categories_with_meta = Category.where.not(meta_title: [ nil, "" ]).where.not(meta_description: [ nil, "" ]).count
    categories_total = Category.count

    puts "\nCategories:"
    puts "  With complete meta: #{categories_with_meta}/#{categories_total}"
    puts "  Missing meta: #{categories_total - categories_with_meta}"

    # Product stats
    products_with_meta = Product.where.not(meta_title: [ nil, "" ]).where.not(meta_description: [ nil, "" ]).count
    products_total = Product.count

    puts "\nProducts:"
    puts "  With complete meta: #{products_with_meta}/#{products_total}"
    puts "  Missing meta: #{products_total - products_with_meta}"

    # Description stats
    products_with_short = Product.where.not(description_short: [ nil, "" ]).count
    products_with_standard = Product.where.not(description_standard: [ nil, "" ]).count
    products_with_detailed = Product.where.not(description_detailed: [ nil, "" ]).count

    puts "\nProduct Descriptions:"
    puts "  With short description: #{products_with_short}/#{products_total}"
    puts "  With standard description: #{products_with_standard}/#{products_total}"
    puts "  With detailed description: #{products_with_detailed}/#{products_total}"

    puts "\n" + "=" * 60
  end
end
