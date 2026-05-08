namespace :products do
  desc "Backfill products.product_family_id by grouping on (brand, name) (DRY_RUN=1 to preview)"
  task backfill_product_family: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    scope = Product.where(product_family_id: nil).where.not(name: [ nil, "" ])

    puts "Scanning #{scope.count} products with no product_family_id set..."
    puts "DRY RUN — no writes" if dry_run

    # Group products by (brand, name). Brand-less products keep their bare name
    # so an Afida "Single Wall Coffee Cups" doesn't collide with a Vegware one.
    by_key = scope.group_by { |p| [ p.brand.presence, p.name ] }

    created_families = 0
    assigned = 0
    skipped_solo = 0

    by_key.each do |(brand, name), products|
      if products.size < 2
        skipped_solo += 1
        next
      end

      family_name = brand.present? ? "#{brand} #{name}" : name
      family_slug = family_name.parameterize

      family = ProductFamily.find_by(slug: family_slug)
      if family.nil?
        if dry_run
          puts "  + would create family #{family_name.inspect} (slug=#{family_slug})"
        else
          family = ProductFamily.create!(name: family_name, slug: family_slug)
        end
        created_families += 1
      end

      products.each do |product|
        puts "    #{product.sku.to_s.ljust(24)} → #{family_name}"
        product.update_column(:product_family_id, family.id) unless dry_run || family.nil?
        assigned += 1
      end
    end

    puts ""
    puts "Families #{dry_run ? 'that would be created' : 'created'}: #{created_families}"
    puts "Products #{dry_run ? 'that would be assigned' : 'assigned'}: #{assigned}"
    puts "Skipped (solo (brand, name)): #{skipped_solo}"
    puts ""
    puts dry_run ? "DRY RUN complete — re-run without DRY_RUN=1 to apply." : "Backfill complete."
  end
end
