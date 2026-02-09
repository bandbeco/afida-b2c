# frozen_string_literal: true

namespace :branded_products do
  desc "Create Greaseproof Paper branded product with tiered pricing"
  task create_greaseproof_paper: :environment do
    puts "Creating Greaseproof Paper branded product..."

    # Find branded products category
    branded_category = Category.find_by(slug: "branded-products")
    unless branded_category
      puts "ERROR: Branded Products category not found (slug: 'branded-products')"
      exit 1
    end

    # =========================================================================
    # PRICING DATA
    # One product with 8 configurable variants (encoded as "size" dimension):
    #   2 paper sizes (A4/A3) × 2 paper types (White/Kraft) × 2 colour options
    #
    # White and Kraft share identical pricing within each size/colour combo
    # but remain separate "sizes" for distinct ordering and fulfilment.
    # =========================================================================

    pricing = [
      # A3 Kraft 1 Colour
      { size: "A3 Kraft 1 Colour",    quantity: 1000,  price: 0.2340 },
      { size: "A3 Kraft 1 Colour",    quantity: 2000,  price: 0.1720 },
      { size: "A3 Kraft 1 Colour",    quantity: 3000,  price: 0.1430 },
      { size: "A3 Kraft 1 Colour",    quantity: 4000,  price: 0.1240 },
      { size: "A3 Kraft 1 Colour",    quantity: 5000,  price: 0.1130 },
      { size: "A3 Kraft 1 Colour",    quantity: 10000, price: 0.0890 },
      { size: "A3 Kraft 1 Colour",    quantity: 20000, price: 0.0846 },
      { size: "A3 Kraft 1 Colour",    quantity: 30000, price: 0.0771 },

      # A3 Kraft 2 Colours
      { size: "A3 Kraft 2 Colours",   quantity: 1000,  price: 0.3060 },
      { size: "A3 Kraft 2 Colours",   quantity: 2000,  price: 0.2030 },
      { size: "A3 Kraft 2 Colours",   quantity: 3000,  price: 0.1620 },
      { size: "A3 Kraft 2 Colours",   quantity: 4000,  price: 0.1440 },
      { size: "A3 Kraft 2 Colours",   quantity: 5000,  price: 0.1320 },
      { size: "A3 Kraft 2 Colours",   quantity: 10000, price: 0.0990 },
      { size: "A3 Kraft 2 Colours",   quantity: 20000, price: 0.0906 },
      { size: "A3 Kraft 2 Colours",   quantity: 30000, price: 0.0819 },

      # A3 White 1 Colour
      { size: "A3 White 1 Colour",    quantity: 1000,  price: 0.2340 },
      { size: "A3 White 1 Colour",    quantity: 2000,  price: 0.1720 },
      { size: "A3 White 1 Colour",    quantity: 3000,  price: 0.1430 },
      { size: "A3 White 1 Colour",    quantity: 4000,  price: 0.1240 },
      { size: "A3 White 1 Colour",    quantity: 5000,  price: 0.1130 },
      { size: "A3 White 1 Colour",    quantity: 10000, price: 0.0890 },
      { size: "A3 White 1 Colour",    quantity: 20000, price: 0.0846 },
      { size: "A3 White 1 Colour",    quantity: 30000, price: 0.0771 },

      # A3 White 2 Colours
      { size: "A3 White 2 Colours",   quantity: 1000,  price: 0.3060 },
      { size: "A3 White 2 Colours",   quantity: 2000,  price: 0.2030 },
      { size: "A3 White 2 Colours",   quantity: 3000,  price: 0.1620 },
      { size: "A3 White 2 Colours",   quantity: 4000,  price: 0.1440 },
      { size: "A3 White 2 Colours",   quantity: 5000,  price: 0.1320 },
      { size: "A3 White 2 Colours",   quantity: 10000, price: 0.0990 },
      { size: "A3 White 2 Colours",   quantity: 20000, price: 0.0906 },
      { size: "A3 White 2 Colours",   quantity: 30000, price: 0.0819 },

      # A4 Kraft 1 Colour
      { size: "A4 Kraft 1 Colour",    quantity: 2000,  price: 0.1170 },
      { size: "A4 Kraft 1 Colour",    quantity: 4000,  price: 0.0860 },
      { size: "A4 Kraft 1 Colour",    quantity: 6000,  price: 0.0715 },
      { size: "A4 Kraft 1 Colour",    quantity: 8000,  price: 0.0623 },
      { size: "A4 Kraft 1 Colour",    quantity: 10000, price: 0.0566 },
      { size: "A4 Kraft 1 Colour",    quantity: 20000, price: 0.0448 },
      { size: "A4 Kraft 1 Colour",    quantity: 30000, price: 0.0445 },

      # A4 Kraft 2 Colours
      { size: "A4 Kraft 2 Colours",   quantity: 2000,  price: 0.1530 },
      { size: "A4 Kraft 2 Colours",   quantity: 4000,  price: 0.1010 },
      { size: "A4 Kraft 2 Colours",   quantity: 6000,  price: 0.0810 },
      { size: "A4 Kraft 2 Colours",   quantity: 8000,  price: 0.0720 },
      { size: "A4 Kraft 2 Colours",   quantity: 10000, price: 0.0660 },
      { size: "A4 Kraft 2 Colours",   quantity: 20000, price: 0.0520 },
      { size: "A4 Kraft 2 Colours",   quantity: 30000, price: 0.0490 },

      # A4 White 1 Colour
      { size: "A4 White 1 Colour",    quantity: 2000,  price: 0.1170 },
      { size: "A4 White 1 Colour",    quantity: 4000,  price: 0.0860 },
      { size: "A4 White 1 Colour",    quantity: 6000,  price: 0.0715 },
      { size: "A4 White 1 Colour",    quantity: 8000,  price: 0.0623 },
      { size: "A4 White 1 Colour",    quantity: 10000, price: 0.0566 },
      { size: "A4 White 1 Colour",    quantity: 20000, price: 0.0448 },
      { size: "A4 White 1 Colour",    quantity: 30000, price: 0.0445 },

      # A4 White 2 Colours
      { size: "A4 White 2 Colours",   quantity: 2000,  price: 0.1530 },
      { size: "A4 White 2 Colours",   quantity: 4000,  price: 0.1010 },
      { size: "A4 White 2 Colours",   quantity: 6000,  price: 0.0810 },
      { size: "A4 White 2 Colours",   quantity: 8000,  price: 0.0720 },
      { size: "A4 White 2 Colours",   quantity: 10000, price: 0.0660 },
      { size: "A4 White 2 Colours",   quantity: 20000, price: 0.0520 },
      { size: "A4 White 2 Colours",   quantity: 30000, price: 0.0490 }
    ]

    case_quantity = 2000
    min_qty = pricing.map { |p| p[:quantity] }.min
    min_qty_formatted = min_qty.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse

    ActiveRecord::Base.transaction do
      # Create one configurable product
      product = Product.find_or_create_by!(slug: "greaseproof-paper", product_type: "customizable_template") do |p|
        p.name = "Greaseproof Paper"
        p.sku = "P-GP"
        p.price = 0.01
        p.category = branded_category
        p.description_short = "Custom branded greaseproof paper with your design. Minimum order: #{min_qty_formatted} units"
        p.description_standard = "Custom branded greaseproof paper with your design. Available in A4 and A3 sizes, White or Kraft paper, 1 or 2 colour print. Minimum order: #{min_qty_formatted} units"
        p.description_detailed = "Custom branded greaseproof paper with your design. Available in A4 (297mm x 210mm) and A3 (420mm x 297mm) sizes, White 38GSM or Kraft 40GSM paper, with 1 or 2 colour printing options. Perfect for food service businesses."
        p.active = true
        p.position = 10
        p.stock_quantity = 0
      end

      # Create pricing tiers for each variant
      total_pricing = 0
      pricing.each do |tier|
        product.branded_product_prices.find_or_create_by!(
          size: tier[:size],
          quantity_tier: tier[:quantity]
        ) do |bp|
          bp.price_per_unit = tier[:price]
          bp.case_quantity = case_quantity
        end
        total_pricing += 1
      end

      sizes = pricing.map { |p| p[:size] }.uniq
      puts "  ✓ #{product.name} (SKU: #{product.sku})"
      puts "    #{sizes.size} configurable variants: #{sizes.join(', ')}"
      puts "    #{total_pricing} pricing tiers total"
    end

    puts ""
    puts "Greaseproof Paper branded product created successfully!"
    puts ""
    puts "Verify with:"
    puts "  rails branded_products:list"
    puts "  rails branded_products:show[greaseproof-paper]"
  end
end
