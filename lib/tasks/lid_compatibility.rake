namespace :lid_compatibility do
  # One-time cleanup before the storefront stopped size-filtering curated lids
  # at render time: rewrites family-seeded join rows to the set the old regex
  # filter actually displayed, so removing the filter changes nothing visually.
  # Branded templates are skipped: one template spans many cup sizes and its
  # rows are filtered per selected size by the configurator at runtime.
  desc "Delete join rows whose lid oz size mismatches the product's (dry run unless APPLY=1)"
  task prune_size_mismatched: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "Applying prune..." : "DRY RUN (set APPLY=1 to write)"
    deleted_total = 0

    product_ids = ProductCompatibleLid.unscoped.distinct.pluck(:product_id)
    Product.unscoped.where(id: product_ids, product_type: "standard").find_each do |product|
      rows = ProductCompatibleLid.where(product_id: product.id).includes(:compatible_lid).order(:sort_order)
      product_token = product.oz_size_token
      doomed, kept = rows.partition { |row| product_token.nil? || row.compatible_lid.oz_size_token != product_token }
      next if doomed.empty?

      puts "#{product.name} [#{product.sku}] (#{product_token || 'no oz token'})"
      puts "  removing: #{doomed.map { |r| r.compatible_lid.sku }.join(', ')}"
      puts "  keeping:  #{kept.any? ? kept.map { |r| r.compatible_lid.sku }.join(', ') : '(none)'}"
      deleted_total += doomed.size
      next unless apply

      # Destroying a default promotes a survivor via the model callback
      doomed.each(&:destroy!)
    end

    puts "#{apply ? 'Deleted' : 'Would delete'} #{deleted_total} rows; #{ProductCompatibleLid.count} remain"
  end

  desc "Display lid compatibility report"
  task report: :environment do
    puts "\n" + "=" * 80
    puts "LID COMPATIBILITY REPORT"
    puts "=" * 80

    cup_ids = ProductCompatibleLid.unscoped.distinct.pluck(:product_id)
    cups_with_lids = Product.unscoped
                            .where(id: cup_ids)
                            .includes(:product_family)
                            .order("product_families.name NULLS LAST", :name, :sku)
                            .references(:product_family)

    if cups_with_lids.empty?
      puts "\nNo lid compatibility data found."
      puts "Populate via the lids: pipeline (lids:export_inventory -> lids:propose_mappings -> lids:apply_mappings) or the admin Compatible Lids panel."
      return
    end

    current_family = nil

    cups_with_lids.each do |cup|
      # Print family header when it changes
      family_name = cup.product_family&.name || "No Family"
      if family_name != current_family
        puts "\n" + "-" * 80
        puts "#{family_name}"
        puts "-" * 80
        current_family = family_name
      end

      type_label = cup.product_type == "customizable_template" ? " (branded)" : ""
      puts "\n  #{cup.name} [#{cup.sku}]#{type_label}"

      ProductCompatibleLid.where(product_id: cup.id)
                          .includes(:compatible_lid)
                          .order(:sort_order)
                          .each do |pcl|
        default_marker = pcl.default? ? " [DEFAULT]" : ""
        puts "    #{pcl.sort_order + 1}. #{pcl.compatible_lid.name} [#{pcl.compatible_lid.sku}]#{default_marker}"
      end
    end

    puts "\n" + "=" * 80
    puts "Summary"
    puts "=" * 80
    puts "Total cups with lids: #{cups_with_lids.count}"
    puts "Total relationships: #{ProductCompatibleLid.count}"
    puts "=" * 80
  end

  desc "Clear all lid compatibility data"
  task clear: :environment do
    count = ProductCompatibleLid.count
    ProductCompatibleLid.destroy_all
    puts "Cleared #{count} lid compatibility relationships"
  end
end
