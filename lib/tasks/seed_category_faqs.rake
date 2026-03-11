# frozen_string_literal: true

namespace :categories do
  desc "Seed category FAQs from config/category_faqs.yml into the database"
  task seed_faqs: :environment do
    yaml_path = Rails.root.join("config/category_faqs.yml")
    unless File.exist?(yaml_path)
      puts "No category_faqs.yml found, skipping."
      next
    end

    faqs_data = YAML.load_file(yaml_path)
    updated = 0
    skipped = 0

    faqs_data.each do |slug, faqs|
      category = Category.find_by(slug: slug)
      if category.nil?
        puts "  SKIP: No category with slug '#{slug}'"
        skipped += 1
        next
      end

      if category.faqs.present?
        puts "  SKIP: #{slug} already has #{category.faqs.size} FAQs"
        skipped += 1
        next
      end

      category.update!(faqs: faqs)
      puts "  OK: #{slug} — #{faqs.size} FAQs"
      updated += 1
    end

    puts "\nDone. Updated: #{updated}, Skipped: #{skipped}"
  end
end
