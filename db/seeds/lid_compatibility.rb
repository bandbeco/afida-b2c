# Seed lid compatibility relationships between cups and lids
# Uses ProductFamily associations for robust matching
puts "Populating lid compatibility data..."

# Clear existing data
ProductCompatibleLid.destroy_all
puts "Cleared existing compatibility data"

# Define compatibility mappings using ProductFamily names
# Each cup family maps to one or more lid families
COMPATIBILITY_MAPPINGS = [
  {
    cup_family: "Coffee Cups",
    lid_family: "Coffee Cup Lids",
    description: "Hot paper cups → sip lids"
  },
  {
    cup_family: "Smoothie Cups",
    lid_family: "Smoothie Lids",
    description: "Cold plastic cups → dome/flat lids"
  }
].freeze

COMPATIBILITY_MAPPINGS.each do |mapping|
  puts "\n" + "=" * 60
  puts "Processing: #{mapping[:description]}"
  puts "=" * 60

  cup_family = ProductFamily.find_by(name: mapping[:cup_family])
  lid_family = ProductFamily.find_by(name: mapping[:lid_family])

  if cup_family.nil?
    puts "  ⚠ Cup family '#{mapping[:cup_family]}' not found, skipping..."
    next
  end

  if lid_family.nil?
    puts "  ⚠ Lid family '#{mapping[:lid_family]}' not found, skipping..."
    next
  end

  # Get all cup products in this family (both standard and branded)
  cups = Product.unscoped.where(product_family: cup_family)

  # Get all lid products in this family (standard only - lids aren't branded)
  lids = Product.unscoped
                .where(product_family: lid_family)
                .where(product_type: [ nil, "standard" ])
                .order(:name, :sku)

  puts "  Found #{cups.count} cups and #{lids.count} lids"

  cups.each do |cup|
    type_label = cup.product_type == "customizable_template" ? " (branded)" : ""
    puts "\n  Cup: #{cup.name} [#{cup.sku}]#{type_label}"

    lids.each_with_index do |lid, index|
      compatibility = ProductCompatibleLid.create!(
        product: cup,
        compatible_lid: lid,
        sort_order: index,
        default: index == 0
      )
      default_marker = compatibility.default ? " [DEFAULT]" : ""
      puts "    ✓ #{lid.name} [#{lid.sku}]#{default_marker}"
    end
  end
end

# Summary
total_relationships = ProductCompatibleLid.count
cups_with_lids = Product.joins(:product_compatible_lids).distinct.count

puts "\n" + "=" * 60
puts "Lid compatibility population complete!"
puts "=" * 60
puts "Total relationships created: #{total_relationships}"
puts "Cups with compatible lids: #{cups_with_lids}"
