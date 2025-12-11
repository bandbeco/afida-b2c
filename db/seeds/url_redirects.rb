# frozen_string_literal: true

require 'csv'
require 'uri'

# URL Redirects from old afida.com site
# This file seeds the database with mappings from legacy product URLs to new product structure
#
# Source: config/url_redirects.csv
#
# Process:
# 1. Parse CSV file (source, target columns)
# 2. Extract source_path from source column
# 3. Parse target URL to extract target_slug and variant_params
# 4. Create/update UrlRedirect records using idempotent find_or_create_by!

puts "Seeding URL redirects from CSV..."
puts "Reading: #{Rails.root.join('config/url_redirects.csv')}"

# Track statistics
created_count = 0
updated_count = 0
skipped_count = 0
error_count = 0
errors = []
csv_row_count = 0

# Validate CSV file exists
csv_path = Rails.root.join('config/url_redirects.csv')
unless File.exist?(csv_path)
  puts "❌ Error: CSV file not found at #{csv_path}"
  exit 1
end

# Pre-flight validation: Check all target products exist and are active
puts "Validating target products..."
invalid_products = []

CSV.foreach(csv_path, headers: true) do |row|
  next if row['target'].blank?

  begin
    uri = URI.parse(row['target'])
    target_slug = uri.path.sub('/products/', '')

    # Check for active product
    product = Product.find_by(slug: target_slug)

    if product.nil?
      invalid_products << { source: row['source'], target_slug: target_slug }
    end
  rescue StandardError => e
    invalid_products << { source: row['source'], error: e.message }
  end
end

if invalid_products.any?
  puts "❌ Validation failed: #{invalid_products.count} invalid product(s) found"
  invalid_products.each do |item|
    if item[:error]
      puts "  - #{item[:source]}: #{item[:error]}"
    else
      puts "  - #{item[:source]} → product '#{item[:target_slug]}' not found or inactive"
    end
  end
  exit 1
end

puts "✅ All target products validated (#{CSV.read(csv_path, headers: true).count} redirects)"
puts ""

# Wrap seeding in transaction for data integrity
ActiveRecord::Base.transaction do
  # Parse CSV and create redirects
  CSV.foreach(csv_path, headers: true) do |row|
    csv_row_count += 1
    source = row['source']
    target = row['target']

    # Validate row data
    if source.blank? || target.blank?
      error_count += 1
      errors << { row: csv_row_count, error: "Empty source or target" }
      print "E"
      next
    end

    # Extract source path (source is already in the format /product/...)
    source_path = source.strip

    # Parse target URL to extract slug and variant parameters
    begin
      uri = URI.parse(target)

      # Extract target slug from path (remove /products/ prefix)
      target_slug = uri.path.sub('/products/', '')

      # Extract variant parameters from query string
      variant_params = if uri.query
        URI.decode_www_form(uri.query).to_h
      else
        {}
      end

      # Create or update redirect using idempotent find_or_create_by!
      redirect = UrlRedirect.find_or_initialize_by(source_path: source_path)

      if redirect.new_record?
        redirect.target_slug = target_slug
        redirect.variant_params = variant_params
        redirect.active = true
        redirect.save!
        created_count += 1
        print "."
      elsif redirect.target_slug != target_slug || redirect.variant_params != variant_params
        redirect.target_slug = target_slug
        redirect.variant_params = variant_params
        redirect.save!
        updated_count += 1
        print "u"
      else
        skipped_count += 1
        print "-"
      end

    rescue StandardError => e
      error_count += 1
      errors << { source_path: source_path, error: e.message }
      print "E"
    end
  end
end

puts "\n"
puts "=" * 60
puts "✅ Seed completed!"
puts "=" * 60
puts "Processed: #{csv_row_count} rows from CSV"
puts "Created:   #{created_count} new redirects"
puts "Updated:   #{updated_count} existing redirects"
puts "Skipped:   #{skipped_count} unchanged redirects"
puts "Errors:    #{error_count}"
puts ""
puts "Database totals:"
puts "  Active redirects:   #{UrlRedirect.active.count}"
puts "  Inactive redirects: #{UrlRedirect.inactive.count}"
puts "  Total redirects:    #{UrlRedirect.count}"

if errors.any?
  puts ""
  puts "⚠️  Errors encountered:"
  errors.each do |err|
    puts "  - #{err[:source_path]}: #{err[:error]}"
  end
end
