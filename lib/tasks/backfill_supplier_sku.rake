require "csv"

namespace :ppp do
  desc "Backfill products.supplier_sku from the reviewed PPP mapping CSV. " \
       "Dry-run by default; pass APPLY=1 to write."
  task backfill_supplier_sku: :environment do
    csv_file = ENV["CSV"].presence || Rails.root.join("lib", "data", "ppp", "supplier_sku_backfill.csv")
    apply = ENV["APPLY"] == "1"

    unless File.exist?(csv_file)
      puts "Error: CSV not found at #{csv_file}"
      exit 1
    end

    puts(apply ? "APPLYING supplier_sku backfill..." : "DRY RUN (pass APPLY=1 to write)...")
    puts "Source: #{csv_file}"
    puts "=" * 70

    stats = {
      updated: 0,
      already_set: 0,
      unchanged: 0,
      skipped_blank: 0,
      not_found: 0,
      conflicts: []
    }

    CSV.foreach(csv_file, headers: true) do |row|
      production_sku = row["production_sku"]&.strip
      supplier_sku   = row["supplier_sku"]&.strip
      next if production_sku.blank?

      # Rows with no resolved supplier SKU (e.g. seasonal/delisted) are skipped.
      if supplier_sku.blank?
        stats[:skipped_blank] += 1
        puts "  SKIP (no supplier_sku): #{production_sku} (#{row["current_name"]})"
        next
      end

      product = Product.unscoped.find_by(sku: production_sku)
      unless product
        stats[:not_found] += 1
        puts "  MISSING (no product): #{production_sku}"
        next
      end

      current = product.supplier_sku&.strip

      if current == supplier_sku
        stats[:unchanged] += 1
        next
      end

      # Guard: a different supplier_sku already present means someone set it
      # by another route. Don't silently overwrite; report it.
      if current.present?
        stats[:conflicts] << "#{production_sku}: existing '#{current}' vs proposed '#{supplier_sku}'"
        puts "  CONFLICT (already set): #{production_sku} has '#{current}', proposed '#{supplier_sku}' (left unchanged)"
        next
      end

      # Guard: don't create a duplicate supplier_sku on a different product.
      clash = Product.unscoped.where(supplier_sku: supplier_sku).where.not(id: product.id).first
      if clash
        stats[:conflicts] << "#{production_sku}: supplier_sku '#{supplier_sku}' already on #{clash.sku}"
        puts "  CONFLICT (dup supplier_sku): '#{supplier_sku}' already on #{clash.sku} (left unchanged)"
        next
      end

      if apply
        product.update_column(:supplier_sku, supplier_sku)
        stats[:updated] += 1
      else
        stats[:updated] += 1 # counted as "would update" in dry run
      end
      puts "  #{apply ? "SET" : "WOULD SET"}: #{production_sku} -> #{supplier_sku}"
    end

    puts "=" * 70
    puts(apply ? "Backfill complete." : "Dry run complete (no changes written).")
    puts "  #{apply ? "Updated" : "Would update"}: #{stats[:updated]}"
    puts "  Already correct:    #{stats[:unchanged]}"
    puts "  Skipped (blank):    #{stats[:skipped_blank]}"
    puts "  Product not found:  #{stats[:not_found]}"
    puts "  Conflicts:          #{stats[:conflicts].size}"
    stats[:conflicts].each { |c| puts "    - #{c}" }
    puts "=" * 70
    if apply
      populated = Product.unscoped.where.not(supplier_sku: [ nil, "" ]).count
      puts "Products with supplier_sku now: #{populated}"
    end
  end
end
