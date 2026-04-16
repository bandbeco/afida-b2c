require "csv"

namespace :products do
  desc "Import product specifications (dimensions, weight, certifications) from CSV"
  task :import_specs, [ :csv_path ] => :environment do |_t, args|
    csv_file = args[:csv_path] || Rails.root.join("lib", "data", "specs.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Starting specs import from #{csv_file}..."

    stats = { updated: 0, skipped: 0, not_found: 0, errors: [] }
    csv_data = CSV.read(csv_file, headers: true)

    csv_data.each do |row|
      sku = row["afida_sku"]
      next if sku.blank?

      product = Product.find_by(sku: sku)

      unless product
        stats[:not_found] += 1
        puts "  WARNING: SKU #{sku} not found, skipping"
        next
      end

      attrs = {}

      # Product dimensions
      attrs[:length_in_mm] = parse_dimension_to_mm(row["product_length"])
      attrs[:width_in_mm] = parse_dimension_to_mm(row["product_width"])
      attrs[:height_in_mm] = parse_dimension_to_mm(row["product_height"])
      attrs[:weight_in_g] = parse_weight_to_g(row["product_weight"])

      # Case dimensions
      attrs[:case_length_in_mm] = parse_dimension_to_mm(row["case_length"])
      attrs[:case_width_in_mm] = parse_dimension_to_mm(row["case_width"])
      attrs[:case_depth_in_mm] = parse_dimension_to_mm(row["case_depth"])
      attrs[:case_weight_in_g] = parse_weight_to_g(row["case_weight"])

      # Certifications
      certifications = parse_certifications(row["certifications"])
      attrs[:certifications] = certifications if certifications

      # Remove nil values so we don't overwrite existing data with nil
      attrs.compact!

      if attrs.empty?
        stats[:skipped] += 1
        next
      end

      product.update_columns(attrs)
      stats[:updated] += 1
    rescue => e
      stats[:errors] << "#{sku}: #{e.message}"
      puts "  ERROR: #{sku}: #{e.message}"
    end

    puts "\n#{"=" * 60}"
    puts "Specs import completed!"
    puts "=" * 60
    puts "Updated: #{stats[:updated]}"
    puts "Skipped (no data): #{stats[:skipped]}"
    puts "Not found: #{stats[:not_found]}"

    if stats[:errors].any?
      puts "\nErrors (#{stats[:errors].count}):"
      stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts "=" * 60
  end
end

def null_value?(value)
  value.blank? || value.match?(/\A(not specified|n\/a|unknown|null|not provided|undefined|-|\/|0)\z/i)
end

def parse_dimension_to_mm(value)
  return nil if null_value?(value)

  case value.strip
  when /\A(\d+(?:\.\d+)?)\s*mm\z/i
    $1.to_f.round
  when /\A(\d+(?:\.\d+)?)\s*cm\z/i
    ($1.to_f * 10).round
  when /\A(\d+(?:\.\d+)?)\s*(?:inches?|in|″|")\z/i
    ($1.to_f * 25.4).round
  else
    nil
  end
end

def parse_weight_to_g(value)
  return nil if null_value?(value)

  case value.strip
  when /(\d+(?:\.\d+)?)\s*kg/i
    ($1.to_f * 1000).round
  when /(\d+(?:\.\d+)?)\s*g\b/i
    $1.to_f.round
  when /(\d+(?:\.\d+)?)\s*lbs?/i
    ($1.to_f * 453.592).round
  when /(\d+(?:\.\d+)?)\s*oz/i
    ($1.to_f * 28.3495).round
  else
    nil
  end
end

def parse_certifications(value)
  return nil if null_value?(value)

  value.strip.gsub(" / ", ", ").gsub("/", ", ")
end
