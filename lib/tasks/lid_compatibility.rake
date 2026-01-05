namespace :lid_compatibility do
  desc "Populate product_compatible_lids table with default compatibility relationships"
  task populate: :environment do
    load Rails.root.join("db", "seeds", "lid_compatibility.rb")
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
