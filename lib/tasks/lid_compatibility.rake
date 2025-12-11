namespace :lid_compatibility do
  desc "Populate product_compatible_lids table with default compatibility relationships"
  task populate: :environment do
    puts "Populating lid compatibility data..."

    # Clear existing data
    ProductCompatibleLid.destroy_all
    puts "Cleared existing compatibility data"

    # Define hot cup product names (paper-based hot beverage cups)
    hot_cup_names = [
      "Single Wall Hot Cups",
      "Double Wall Hot Cups",
      "Ripple Wall Hot Cups"
    ]

    # Define hot lid product names
    hot_lid_names = [
      "Bagasse Sip Lids for Hot Cups",
      "Recyclable Sip Lids for Hot Cups"
    ]

    # Define cold cup product names (plastic/clear cups)
    cold_cup_names = [
      "rPET Recyclable Cups"
    ]

    # Define cold lid product names
    cold_lid_names = [
      "rPET Dome Lids",
      "rPET Flat Lids"
    ]

    # Populate hot cup → hot lid relationships
    hot_cups = Product.where(name: hot_cup_names)
    hot_lids = Product.where(name: hot_lid_names)

    hot_cups.each do |cup|
      puts "\nProcessing cup: #{cup.name}"

      hot_lids.each_with_index do |lid, index|
        compatibility = ProductCompatibleLid.create!(
          product: cup,
          compatible_lid: lid,
          sort_order: index,
          default: index == 0 # First lid is default
        )
        puts "  ✓ Added compatible lid: #{lid.name} (default: #{compatibility.default})"
      end
    end

    # Populate cold cup → cold lid relationships
    cold_cups = Product.where(name: cold_cup_names)
    cold_lids = Product.where(name: cold_lid_names)

    cold_cups.each do |cup|
      puts "\nProcessing cup: #{cup.name}"

      cold_lids.each_with_index do |lid, index|
        compatibility = ProductCompatibleLid.create!(
          product: cup,
          compatible_lid: lid,
          sort_order: index,
          default: index == 0 # First lid is default
        )
        puts "  ✓ Added compatible lid: #{lid.name} (default: #{compatibility.default})"
      end
    end

    # Summary
    total_relationships = ProductCompatibleLid.count
    cups_with_lids = Product.joins(:product_compatible_lids).distinct.count

    puts "\n" + "="*60
    puts "Lid compatibility population complete!"
    puts "="*60
    puts "Total relationships created: #{total_relationships}"
    puts "Cups with compatible lids: #{cups_with_lids}"
    puts "\nRun 'rails lid_compatibility:report' to see the full compatibility matrix"
  end

  desc "Display lid compatibility report"
  task report: :environment do
    puts "\n" + "="*80
    puts "LID COMPATIBILITY REPORT"
    puts "="*80

    cup_ids = ProductCompatibleLid.unscoped.distinct.pluck(:product_id)
    cups_with_lids = Product.where(id: cup_ids).order(:name)

    if cups_with_lids.empty?
      puts "\nNo lid compatibility data found."
      puts "Run 'rails lid_compatibility:populate' to populate default relationships."
      return
    end

    cups_with_lids.each do |cup|
      puts "\n#{cup.name}"
      puts "-" * 80

      ProductCompatibleLid.where(product_id: cup.id)
                          .includes(:compatible_lid)
                          .order(:sort_order)
                          .each do |pcl|
        default_marker = pcl.default? ? " [DEFAULT]" : ""
        puts "  #{pcl.sort_order + 1}. #{pcl.compatible_lid.name}#{default_marker}"
      end
    end

    puts "\n" + "="*80
    puts "Total cups with lids: #{cups_with_lids.count}"
    puts "Total relationships: #{ProductCompatibleLid.count}"
    puts "="*80
  end

  desc "Clear all lid compatibility data"
  task clear: :environment do
    count = ProductCompatibleLid.count
    ProductCompatibleLid.destroy_all
    puts "Cleared #{count} lid compatibility relationships"
  end
end
