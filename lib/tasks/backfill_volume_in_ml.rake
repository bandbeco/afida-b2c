namespace :products do
  desc "Backfill products.volume_in_ml from products.size strings (DRY_RUN=1 to preview)"
  task backfill_volume_in_ml: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    scope = Product.where(volume_in_ml: nil).where.not(size: [ nil, "" ])

    puts "Scanning #{scope.count} products with no volume_in_ml set..."
    puts "DRY RUN — no writes" if dry_run

    updated = 0
    skipped = 0
    by_pattern = Hash.new(0)

    scope.find_each do |product|
      ml = ProductSizeParser.parse(product.size)

      if ml.nil?
        skipped += 1
        by_pattern[product.size] += 1
        next
      end

      puts "  #{product.sku.to_s.ljust(20)} #{product.size.to_s.ljust(28)} → #{ml}ml"
      product.update_column(:volume_in_ml, ml) unless dry_run
      updated += 1
    end

    puts ""
    puts "Updated: #{updated}"
    puts "Skipped (not a capacity string): #{skipped}"
    if by_pattern.any?
      puts ""
      puts "Skipped size strings (count × value):"
      by_pattern.sort_by { |_, count| -count }.each do |size, count|
        puts "  #{count.to_s.rjust(4)}  #{size.inspect}"
      end
    end
    puts ""
    puts dry_run ? "DRY RUN complete — re-run without DRY_RUN=1 to apply." : "Backfill complete."
  end
end
