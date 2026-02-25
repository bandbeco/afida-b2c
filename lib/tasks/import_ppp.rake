require "csv"

namespace :ppp do
  desc "Import products from Purple Planet Packaging CSV"
  task import: :environment do
    csv_file = Rails.root.join("lib", "data", "ppp", "ppp.csv")
    photos_dir = Rails.root.join("lib", "data", "ppp", "photos")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Starting PPP product import from #{csv_file}..."

    # Map PPP category names to existing DB slugs
    existing_category_slugs = {
      "Cups & Lids" => "cups-and-lids",
      "Ice Cream" => "ice-cream-cups",
      "Napkins" => "napkins",
      "Straws" => "straws",
      "Takeaway Extras" => "takeaway-extras"
    }

    stats = {
      created: 0,
      updated: 0,
      skipped_no_price: 0,
      categories_created: 0,
      photos_attached: 0,
      with_pricing_tiers: 0,
      errors: []
    }

    category_cache = {}

    CSV.foreach(csv_file, headers: true) do |row|
      sku = row["sku"]&.strip
      next if sku.blank?

      # Skip rows without a price
      price_str = row["pack_price"]&.strip
      if price_str.blank?
        stats[:skipped_no_price] += 1
        puts "  Skipped (no price): #{sku}"
        next
      end

      begin
        # Find or create category
        category_name = row["category"]&.strip
        category = category_cache[category_name] ||= begin
          slug = existing_category_slugs[category_name] || category_name.parameterize
          Category.find_or_create_by!(slug: slug) do |cat|
            cat.name = category_name
            stats[:categories_created] += 1
            puts "  Created category: #{category_name} (#{slug})"
          end
        end

        # Parse pricing tiers from variant column
        pricing_tiers = parse_pricing_tiers(row["quantity_variant_size_and_price"])

        # Shared attributes for both create and update
        attributes = {
          name: row["name"]&.strip,
          brand: row["brand"]&.strip.presence,
          category: category,
          price: BigDecimal(price_str),
          colour: row["colour"]&.strip.presence,
          material: row["material"]&.strip.presence,
          pac_size: row["pack_size"]&.strip.presence&.to_i,
          description_detailed: row["description_detailed"]&.strip.presence,
          description_short: row["description_short"]&.strip.presence,
          description_standard: row["description_standard"]&.strip.presence,
          meta_title: row["meta_title"]&.strip.presence,
          meta_description: row["meta_description"]&.strip.presence,
          size: row["size"]&.strip.presence,
          pricing_tiers: pricing_tiers,
          certifications: row["certifications"]&.strip.presence
        }

        existing = Product.unscoped.find_by(sku: sku)

        if existing
          existing.update!(attributes)
          stats[:updated] += 1
          puts "  Updated: #{existing.name} (#{sku})"
        else
          product = Product.create!(
            attributes.merge(
              sku: sku,
              active: true,
              product_type: "standard",
              stock_quantity: 0
            )
          )

          # Attach photo if available
          photo_path = photos_dir.join("#{sku}.jpg")
          if File.exist?(photo_path)
            product.product_photo.attach(
              io: File.open(photo_path),
              filename: "#{sku}.jpg",
              content_type: "image/jpeg"
            )
            stats[:photos_attached] += 1
          end

          stats[:created] += 1
          stats[:with_pricing_tiers] += 1 if pricing_tiers.present?
          puts "  Created: #{product.name} (#{sku})"
        end

      rescue => e
        error_msg = "Error processing #{sku}: #{e.message}"
        stats[:errors] << error_msg
        puts "  ERROR: #{error_msg}"
        puts "  #{e.backtrace.first}"
      end
    end

    # Print summary
    puts "\n" + "=" * 60
    puts "PPP Import completed!"
    puts "=" * 60
    puts "Products created:      #{stats[:created]}"
    puts "Products updated:      #{stats[:updated]}"
    puts "Skipped (no price):    #{stats[:skipped_no_price]}"
    puts "Categories created:    #{stats[:categories_created]}"
    puts "Photos attached:       #{stats[:photos_attached]}"
    puts "With pricing tiers:    #{stats[:with_pricing_tiers]}"

    if stats[:errors].any?
      puts "\nErrors (#{stats[:errors].count}):"
      stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts "=" * 60
    puts "Total products now: #{Product.unscoped.count}"
    puts "Total categories now: #{Category.count}"
  end
end

# Parse variant pricing string into sorted tiers array.
#
# Handles two formats:
#   "Case (600): £148.22 | Pack (50): £27.11"
#   "Case of 5000: £102.71 | Pack of 250: £12.36"
#
# Returns: [{"quantity" => 50, "price" => "27.11"}, {"quantity" => 600, "price" => "148.22"}]
# or nil if input is blank or unparseable.
def parse_pricing_tiers(raw)
  return nil if raw.blank?

  tiers = raw.strip.split("|").filter_map do |segment|
    segment = segment.strip
    # Match "Label (qty): £price" or "Label of qty: £price"
    if segment =~ /\((\d+)\):\s*£([\d.]+)/ || segment =~ /of\s+(\d+):\s*£([\d.]+)/
      { "quantity" => $1.to_i, "price" => $2 }
    end
  end

  return nil if tiers.empty?

  tiers.sort_by { |t| t["quantity"] }
end
