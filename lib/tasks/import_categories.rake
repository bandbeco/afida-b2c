require "csv"

namespace :categories do
  desc "Import or update categories from CSV file (SEO metadata and descriptions)"
  task import: :environment do
    csv_file = Rails.root.join("lib", "data", "categories.csv")

    unless File.exist?(csv_file)
      puts "Error: CSV file not found at #{csv_file}"
      exit 1
    end

    puts "Starting category import from #{csv_file}..."

    stats = {
      categories_created: 0,
      categories_updated: 0,
      errors: []
    }

    csv = CSV.read(csv_file, headers: true)

    # Without this column every row looks top-level, and `parent:` below would
    # move all 33 categories to the root, breaking every nested category URL.
    unless csv.headers.include?("parent_slug")
      puts "Error: #{csv_file} is missing the parent_slug column — refusing to flatten the taxonomy"
      exit 1
    end

    rows = csv.map(&:to_h)

    # Parents first: a subcategory cannot resolve its parent_slug until the
    # parent row exists. Mirrors the two-pass load in db/seeds.rb.
    # partition, not sort_by: Ruby's sort is not stable, and CSV row order sets
    # acts_as_list positions on first create.
    parents_first = rows.reject { |r| r["slug"].to_s.strip.blank? }
                        .partition { |r| r["parent_slug"].blank? }
                        .flatten(1)
    parents = {}

    parents_first.each do |row|
      slug = row["slug"].strip
      parent_slug = row["parent_slug"]&.strip

      begin
        parent =
          if parent_slug.blank?
            nil
          else
            parents[parent_slug] || Category.find_by(slug: parent_slug) ||
              raise("names unknown parent #{parent_slug.inspect}")
          end

        category = Category.find_or_initialize_by(slug: slug)
        is_new = category.new_record?

        # A blank cell means "no opinion", not "clear it". Most rows ship blank
        # and rely on the model's meta_*_with_fallback, and production holds
        # copy this file does not — assigning nil would wipe it.
        attributes = { name: row["name"]&.strip&.gsub(/\s+/, " "), parent: parent }
        attributes[:meta_title] = row["meta_title"].strip if row["meta_title"].present?
        attributes[:meta_description] = row["meta_description"].strip.gsub(/\s+/, " ") if row["meta_description"].present?
        attributes[:description] = row["description"].strip if row["description"].present?

        category.assign_attributes(attributes)

        if category.changed?
          category.save!
          parents[slug] = category if parent_slug.blank?
          if is_new
            stats[:categories_created] += 1
            puts "  Created: #{category.name} (#{slug})"
          else
            stats[:categories_updated] += 1
            puts "  Updated: #{category.name} (#{slug})"
          end
        else
          parents[slug] = category if parent_slug.blank?
          puts "  Unchanged: #{category.name} (#{slug})"
        end

      rescue => e
        error_msg = "Error processing category #{slug}: #{e.message}"
        stats[:errors] << error_msg
        puts "  ERROR: #{error_msg}"
      end
    end

    # Print summary
    puts "\n" + "=" * 60
    puts "Import completed!"
    puts "=" * 60
    puts "Categories created: #{stats[:categories_created]}"
    puts "Categories updated: #{stats[:categories_updated]}"
    puts "Total categories: #{Category.count}"

    if stats[:errors].any?
      puts "\nErrors (#{stats[:errors].count}):"
      stats[:errors].each { |error| puts "  - #{error}" }
    end

    puts "=" * 60

    # A per-row rescue plus a zero exit status makes a run that skipped half the
    # taxonomy indistinguishable from a clean one to any calling script.
    exit 1 if stats[:errors].any?
  end

  desc "Validate category SEO data coverage"
  task validate: :environment do
    puts "Validating category SEO data..."
    puts "=" * 60

    issues = []

    Category.find_each do |category|
      category_issues = []
      category_issues << "missing meta_title" if category.meta_title.blank?
      category_issues << "missing meta_description" if category.meta_description.blank?
      category_issues << "missing description" if category.description.blank?
      category_issues << "meta_title too long (#{category.meta_title.length} chars)" if category.meta_title.present? && category.meta_title.length > 60
      category_issues << "meta_description too long (#{category.meta_description.length} chars)" if category.meta_description.present? && category.meta_description.length > 160

      if category_issues.any?
        issues << { category: category, issues: category_issues }
      end
    end

    if issues.any?
      puts "Found #{issues.count} categories with SEO issues:\n"
      issues.each do |item|
        puts "  #{item[:category].name} (#{item[:category].slug}):"
        item[:issues].each { |issue| puts "    - #{issue}" }
      end
    else
      puts "All categories have complete SEO data!"
    end

    puts "\n" + "=" * 60
    puts "Summary:"
    puts "  Total categories: #{Category.count}"
    puts "  Categories with issues: #{issues.count}"
    puts "  Categories complete: #{Category.count - issues.count}"
    puts "=" * 60
  end
end
