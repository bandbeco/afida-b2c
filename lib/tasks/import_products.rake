require "csv"

namespace :products do
  desc "Import or update products from CSV file"
  task import: :environment do
    csv_file = Rails.root.join("lib", "data", "products.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Starting product import from #{csv_file}..."

    stats = {
      products_created: 0,
      products_updated: 0,
      variants_created: 0,
      variants_updated: 0,
      categories_created: 0,
      options_created: 0,
      errors: []
    }

    # Parse CSV and group by product
    csv_data = CSV.read(csv_file, headers: true)
    products_data = csv_data.group_by { |row| [ row["product"], row["slug"] ] }

    products_data.each do |(product_name, slug), rows|
      # Skip empty rows
      next if product_name.blank? || slug.blank?

      begin
        # Find or create category
        category_slug = rows.first["category"]
        category = Category.find_or_create_by!(slug: category_slug) do |cat|
          # Convert slug back to proper name (titleize)
          cat.name = category_slug.split("-").map(&:capitalize).join(" ")
          stats[:categories_created] += 1
          puts "  Created category: #{cat.name} (#{category_slug})"
        end

        # Find existing product or create new one
        product = Product.unscoped.find_by(slug: slug)
        is_new_product = product.nil?

        if product
          # Update existing product
          product.update!(
            name: product_name,
            category: category,
            active: true
          )
        else
          # Create new product
          product = Product.create!(
            name: product_name,
            slug: slug,
            category: category,
            active: true,
            product_type: "standard"
          )
        end

        # Set meta fields from first variant
        first_row = rows.first
        if first_row["meta_title"].present?
          product.update_column(:meta_title, first_row["meta_title"])
        end
        if first_row["meta_description"].present?
          product.update_column(:meta_description, first_row["meta_description"])
        end

        if is_new_product
          stats[:products_created] += 1
          puts "Created product: #{product_name} (#{slug})"
        else
          stats[:products_updated] += 1
          puts "Updated product: #{product_name} (#{slug})"
        end

        # Create product options if they don't exist
        option_types = []

        if rows.any? { |r| r["material_label"].present? && r["material_value"].present? }
          material_option = ProductOption.find_or_create_by!(name: "material") do |opt|
            opt.display_type = "dropdown"
            opt.position = 1
            stats[:options_created] += 1
          end
          option_types << :material
        end

        if rows.any? { |r| r["size_label"].present? && r["size_value"].present? }
          size_option = ProductOption.find_or_create_by!(name: "size") do |opt|
            opt.display_type = "dropdown"
            opt.position = 2
            stats[:options_created] += 1
          end
          option_types << :size
        end

        if rows.any? { |r| r["colour_label"].present? && r["colour_value"].present? }
          colour_option = ProductOption.find_or_create_by!(name: "colour") do |opt|
            opt.display_type = "dropdown"
            opt.position = 3
            stats[:options_created] += 1
          end
          option_types << :colour
        end

        # Associate options with product
        option_types.each do |option_type|
          option = ProductOption.find_by(name: option_type.to_s)
          unless product.options.include?(option)
            product.option_assignments.create!(product_option: option)
          end
        end

        # Process each variant
        rows.each_with_index do |row, index|
          sku = row["sku"]
          next if sku.blank?

          variant = product.variants.find_or_initialize_by(sku: sku)
          is_new_variant = variant.new_record?

          # Build option values hash
          option_values = {}
          option_values["material"] = row["material_value"] if row["material_value"].present?
          option_values["size"] = row["size_value"] if row["size_value"].present?
          option_values["colour"] = row["colour_value"] if row["colour_value"].present?

          # Parse price (remove currency symbols)
          price_str = row["price"].to_s.gsub(/[£$,]/, "").strip
          price = price_str.to_f

          variant.assign_attributes(
            name: row["size_label"].presence || row["colour_label"].presence || "Standard",
            price: price,
            pac_size: row["pac_size"].to_i,
            active: true,
            position: index + 1,
            option_values: option_values
          )

          variant.save!

          if is_new_variant
            stats[:variants_created] += 1
            puts "  Created variant: #{variant.name} (#{sku})"
          else
            stats[:variants_updated] += 1
            puts "  Updated variant: #{variant.name} (#{sku})"
          end
        end

      rescue => e
        error_msg = "Error processing product #{product_name}: #{e.message}"
        stats[:errors] << error_msg
        puts "  ERROR: #{error_msg}"
        puts "  #{e.backtrace.first}"
      end
    end

    # Print summary
    puts "\n" + "=" * 60
    puts "Import completed!"
    puts "=" * 60
    puts "Products created: #{stats[:products_created]}"
    puts "Products updated: #{stats[:products_updated]}"
    puts "Variants created: #{stats[:variants_created]}"
    puts "Variants updated: #{stats[:variants_updated]}"
    puts "Categories created: #{stats[:categories_created]}"
    puts "Options created: #{stats[:options_created]}"

    if stats[:errors].any?
      puts "\nErrors (#{stats[:errors].count}):"
      stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts "=" * 60
  end
end
