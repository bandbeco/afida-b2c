# frozen_string_literal: true

namespace :legacy_redirects do
  desc "Import legacy redirects from CSV file (config/legacy_redirects.csv)"
  task import: :environment do
    puts "Loading legacy redirects seed file..."
    load Rails.root.join("db/seeds/legacy_redirects.rb")
  end

  desc "Validate all legacy redirects (checks model validations and variant matches)"
  task validate: :environment do
    puts "Validating legacy redirects..."

    total = LegacyRedirect.count
    active = LegacyRedirect.active.count
    inactive = LegacyRedirect.inactive.count
    invalid = 0
    variant_mismatches = 0

    LegacyRedirect.find_each do |redirect|
      # Check model validations
      unless redirect.valid?
        invalid += 1
        puts "  ❌ Invalid: #{redirect.legacy_path} - #{redirect.errors.full_messages.join(', ')}"
      end

      # Check if variant params match actual product variants
      if redirect.target_slug.present? && redirect.variant_params.present?
        product = Product.find_by(slug: redirect.target_slug)
        if product
          matching_variants = product.active_variants.select do |variant|
            redirect.variant_params.all? do |key, value|
              variant.option_values[key] == value
            end
          end

          if matching_variants.empty?
            variant_mismatches += 1
            puts "  ⚠️  Variant mismatch: #{redirect.legacy_path}"
            puts "      Target: #{redirect.target_slug} with #{redirect.variant_params.inspect}"
            puts "      No matching variant found in product"
          end
        end
      end
    end

    puts "\nSummary:"
    puts "  Total: #{total}"
    puts "  Active: #{active}"
    puts "  Inactive: #{inactive}"
    puts "  Invalid: #{invalid}"
    puts "  Variant Mismatches: #{variant_mismatches}"

    if invalid.zero? && variant_mismatches.zero?
      puts "\n✅ All redirects are valid"
    else
      puts "\n⚠️  #{invalid} invalid redirect(s) and #{variant_mismatches} variant mismatch(es) found"
      exit 1
    end
  end

  desc "Generate usage report for legacy redirects"
  task report: :environment do
    puts "Legacy Redirects Usage Report"
    puts "=" * 80

    total_hits = LegacyRedirect.sum(:hit_count)

    puts "\nOverall Statistics:"
    puts "  Total Redirects: #{LegacyRedirect.count}"
    puts "  Active: #{LegacyRedirect.active.count}"
    puts "  Inactive: #{LegacyRedirect.inactive.count}"
    puts "  Total Hits: #{total_hits}"

    puts "\nTop 10 Most Used Redirects:"
    LegacyRedirect.active.most_used.limit(10).each_with_index do |redirect, index|
      puts "  #{index + 1}. #{redirect.legacy_path} → #{redirect.target_slug} (#{redirect.hit_count} hits)"
    end

    unused = LegacyRedirect.active.where(hit_count: 0)
    if unused.any?
      puts "\nUnused Active Redirects (#{unused.count}):"
      unused.each do |redirect|
        puts "  - #{redirect.legacy_path} → #{redirect.target_slug}"
      end
    end

    puts "\n" + "=" * 80
  end

  desc "Report unused redirects (hit_count = 0)"
  task report_unused: :environment do
    unused = LegacyRedirect.active.where(hit_count: 0)

    puts "Unused Active Redirects: #{unused.count}"

    unused.each do |redirect|
      puts "  #{redirect.legacy_path} → #{redirect.target_slug} (created: #{redirect.created_at.to_date})"
    end

    if unused.any?
      puts "\n💡 Consider reviewing these redirects - they may not be needed or have incorrect paths"
    else
      puts "\n✅ All active redirects have been used at least once"
    end
  end

  desc "Check for orphaned redirects (target products no longer exist)"
  task check_orphaned: :environment do
    puts "Checking for orphaned redirects..."

    orphaned = []
    LegacyRedirect.active.find_each do |redirect|
      unless Product.exists?(slug: redirect.target_slug)
        orphaned << redirect
        puts "  ❌ Orphaned: #{redirect.legacy_path} → #{redirect.target_slug} (product not found)"
      end
    end

    puts "\nSummary:"
    puts "  Total Active: #{LegacyRedirect.active.count}"
    puts "  Orphaned: #{orphaned.count}"

    if orphaned.any?
      puts "\n⚠️  Found #{orphaned.count} orphaned redirect(s)"
      puts "💡 Consider deactivating or updating these redirects"
    else
      puts "\n✅ No orphaned redirects found - all target products exist"
    end
  end

  desc "Export redirects to CSV file"
  task :export, [ :file_path ] => :environment do |_t, args|
    require "csv"

    file_path = args[:file_path] || Rails.root.join("tmp/legacy_redirects_export.csv")

    puts "Exporting redirects to #{file_path}..."

    CSV.open(file_path, "wb") do |csv|
      # Write header
      csv << [ "source", "target" ]

      # Write redirects (active only by default)
      LegacyRedirect.active.order(:legacy_path).each do |redirect|
        target_url = "/products/#{redirect.target_slug}"
        if redirect.variant_params.present?
          query_params = redirect.variant_params.to_query
          target_url += "?#{query_params}"
        end

        csv << [ redirect.legacy_path, target_url ]
      end
    end

    puts "✅ Exported #{LegacyRedirect.active.count} redirects to #{file_path}"
  end

  desc "List all redirects with product and variant details"
  task list: :environment do
    puts "Legacy Redirects List"
    puts "=" * 100

    LegacyRedirect.active.order(:legacy_path).each do |redirect|
      product = Product.find_by(slug: redirect.target_slug)

      puts "\n#{redirect.legacy_path}"
      puts "  → /products/#{redirect.target_slug}"

      if product
        puts "  Product: #{product.name}"

        if redirect.variant_params.present?
          puts "  Variant params: #{redirect.variant_params.inspect}"

          # Try to find matching variant
          matching_variants = product.active_variants.select do |variant|
            redirect.variant_params.all? do |key, value|
              variant.option_values[key] == value
            end
          end

          if matching_variants.any?
            puts "  ✅ Matches variant: #{matching_variants.first.name}"
          else
            puts "  ⚠️  No matching variant found!"
          end
        end
      else
        puts "  ❌ Product not found!"
      end

      puts "  Hits: #{redirect.hit_count}"
    end

    puts "\n" + "=" * 100
    puts "Total: #{LegacyRedirect.active.count} active redirects"
  end
end
