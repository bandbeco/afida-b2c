# frozen_string_literal: true

require 'csv'
require 'uri'

# Legacy URL Redirects from old afida.com site
# This file seeds the database with mappings from legacy product URLs to new product structure
#
# Source: config/legacy_redirects.csv
#
# Process:
# 1. Parse CSV file (source, target columns)
# 2. Extract legacy_path from source column
# 3. Parse target URL to extract target_slug and variant_params
# 4. Create/update LegacyRedirect records using idempotent find_or_create_by!

puts "Seeding legacy redirects from CSV..."
puts "Reading: #{Rails.root.join('config/legacy_redirects.csv')}"

# Track statistics
created_count = 0
updated_count = 0
error_count = 0
errors = []

# Parse CSV and create redirects
CSV.foreach(Rails.root.join('config/legacy_redirects.csv'), headers: true) do |row|
  source = row['source']
  target = row['target']

  # Extract legacy path (source is already in the format /product/...)
  legacy_path = source

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
    redirect = LegacyRedirect.find_or_initialize_by(legacy_path: legacy_path)

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
      print "-"
    end

  rescue StandardError => e
    error_count += 1
    errors << { legacy_path: legacy_path, error: e.message }
    print "E"
  end
end

puts "\n"
puts "=" * 60
puts "✅ Seed completed!"
puts "=" * 60
puts "Created:  #{created_count} new redirects"
puts "Updated:  #{updated_count} existing redirects"
puts "Skipped:  #{LegacyRedirect.count - created_count - updated_count} unchanged redirects"
puts "Errors:   #{error_count}"
puts ""
puts "Database totals:"
puts "  Active redirects:   #{LegacyRedirect.active.count}"
puts "  Inactive redirects: #{LegacyRedirect.inactive.count}"
puts "  Total redirects:    #{LegacyRedirect.count}"

if errors.any?
  puts ""
  puts "⚠️  Errors encountered:"
  errors.each do |err|
    puts "  - #{err[:legacy_path]}: #{err[:error]}"
  end
end
