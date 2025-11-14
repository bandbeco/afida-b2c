# frozen_string_literal: true

namespace :legacy_redirects do
  desc "Import legacy redirects from CSV file"
  task import: :environment do
    puts "Loading legacy redirects seed file..."
    load Rails.root.join("db/seeds/legacy_redirects.rb")
  end

  desc "Validate all legacy redirects"
  task validate: :environment do
    puts "Validating legacy redirects..."

    total = LegacyRedirect.count
    active = LegacyRedirect.active.count
    inactive = LegacyRedirect.inactive.count
    invalid = 0

    LegacyRedirect.find_each do |redirect|
      unless redirect.valid?
        invalid += 1
        puts "  ❌ Invalid: #{redirect.legacy_path} - #{redirect.errors.full_messages.join(', ')}"
      end
    end

    puts "\nSummary:"
    puts "  Total: #{total}"
    puts "  Active: #{active}"
    puts "  Inactive: #{inactive}"
    puts "  Invalid: #{invalid}"

    if invalid.zero?
      puts "\n✅ All redirects are valid"
    else
      puts "\n⚠️  #{invalid} invalid redirect(s) found"
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
end
