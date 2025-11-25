# frozen_string_literal: true

namespace :cleanup do
  desc "Remove duplicate branded products (keep ones without 'branded-' prefix)"
  task branded_slugs: :environment do
    puts "Cleaning up duplicate branded products..."
    puts "=" * 80
    puts ""

    # Find all branded products with 'branded-' prefix
    products_to_delete = Product.branded.where("slug LIKE ?", "branded-%")

    if products_to_delete.empty?
      puts "✅ No branded products with 'branded-' prefix found"
      exit 0
    end

    puts "Found #{products_to_delete.count} duplicate branded products to remove:"
    puts ""

    products_to_delete.each do |product|
      target_slug = product.slug.sub(/^branded-/, "")

      # Check if there's a duplicate without the prefix
      duplicate = Product.branded.find_by(slug: target_slug)

      if duplicate
        puts "🗑️  Deleting: #{product.name} (ID: #{product.id})"
        puts "   Slug: #{product.slug}"
        puts "   Keeping: #{duplicate.name} (ID: #{duplicate.id}, slug: #{duplicate.slug})"

        # Delete the product with the branded- prefix
        product.destroy!
        puts "   ✅ Deleted"
      else
        puts "✏️  Renaming: #{product.name}"
        puts "   #{product.slug} → #{target_slug}"
        product.update!(slug: target_slug)
        puts "   ✅ Renamed"
      end

      puts ""
    end

    puts "=" * 80
    puts "Done!"
  end
end
