# Product Consolidation Migration
# Run with: rails runner db/seeds/consolidate_products.rb
#
# This script consolidates multiple related products into single configurable pages:
# - Cocktail Napkins: 3 products → 1 product with material/colour options
# - Dinner Napkins: 4 products → 1 product with material/colour options
# - Straws: 3 products → 1 product with material/size/colour options
# - Wooden Cutlery: 4 products → 1 product with type option
#
# APPROACH: Moves existing variants to new consolidated products (preserves SKUs and order history)
#
# NOTE ON OPTION ARCHITECTURE:
# These consolidated products store options (material, type, colour, size) in the variant's
# `option_values` JSONB column ONLY. They intentionally bypass the ProductOption/ProductOptionValue
# tables because:
#
# 1. Consolidated products use the "product-configurator" Stimulus controller which reads
#    directly from variant JSONB data (see ProductsController#show lines 44-77)
#
# 2. The existing ProductOption "material" has values like "Recyclable, Compostable" (eco-certs),
#    not actual materials like "Paper, Bamboo, Birch" used here - different semantic concepts
#
# 3. ProductOption tables are for standard products using the "product-options" controller,
#    which needs display metadata (dropdown vs swatch, custom labels, ordering)
#
# This is intentional architecture: sparse-matrix products derive their UI from variant data,
# while full-matrix products use ProductOption tables for richer UI controls.

module ProductConsolidation
  class << self
    def run!
      ActiveRecord::Base.transaction do
        consolidate_cocktail_napkins
        consolidate_dinner_napkins
        consolidate_straws
        consolidate_wooden_cutlery

        puts "\n✅ Product consolidation complete!"
        puts "   Run `rails server` and test the consolidated product pages."
      end
    end

    private

    # ===========================================
    # COCKTAIL NAPKINS
    # ===========================================
    def consolidate_cocktail_napkins
      puts "\n📦 Consolidating Cocktail Napkins..."

      napkins_category = Category.find_by!(slug: "napkins")

      # Find source products
      paper_cocktail = Product.find_by(slug: "paper-cocktail-napkins")
      airlaid_cocktail = Product.find_by(slug: "airlaid-cocktail-napkins")
      bamboo_cocktail = Product.find_by(slug: "bamboo-cocktail-napkins")

      # Create consolidated product
      consolidated = Product.find_or_create_by!(slug: "cocktail-napkins") do |p|
        p.name = "Cocktail Napkins"
        p.category = napkins_category
        p.description_short = "Premium cocktail napkins in paper, airlaid, or bamboo."
        p.description_standard = "Eco-friendly cocktail napkins perfect for bars, restaurants, and events. Choose from budget-friendly paper, premium airlaid, or sustainable bamboo options."
        p.description_detailed = "Our cocktail napkin range offers something for every venue and budget. Paper napkins provide excellent value for high-volume use. Airlaid napkins offer a cloth-like feel without the laundry costs. Bamboo napkins are made from rapidly renewable bamboo pulp, making them the most sustainable choice. All options are compostable and food-safe."
        p.active = true
        p.featured = true
      end

      # Build variants with proper option_values
      variants_data = []

      # Paper variants (from paper-cocktail-napkins)
      if paper_cocktail
        paper_cocktail.variants.each do |v|
          variants_data << {
            option_values: {
              "material" => "Paper",
              "colour" => v.option_values["colour"]&.titleize || "White"
            },
            source_variant: v
          }
        end
      end

      # Airlaid variant (from airlaid-cocktail-napkins)
      if airlaid_cocktail
        airlaid_cocktail.variants.each do |v|
          variants_data << {
            option_values: {
              "material" => "Airlaid",
              "colour" => "White"
            },
            source_variant: v
          }
        end
      end

      # Bamboo variant (from bamboo-cocktail-napkins)
      if bamboo_cocktail
        bamboo_cocktail.variants.each do |v|
          variants_data << {
            option_values: {
              "material" => "Bamboo",
              "colour" => "Natural"
            },
            source_variant: v
          }
        end
      end

      move_variants(consolidated, variants_data)
      deactivate_products(paper_cocktail, airlaid_cocktail, bamboo_cocktail)
      puts "   Moved #{variants_data.size} variants to Cocktail Napkins"
    end

    # ===========================================
    # DINNER NAPKINS
    # ===========================================
    def consolidate_dinner_napkins
      puts "\n📦 Consolidating Dinner Napkins..."

      napkins_category = Category.find_by!(slug: "napkins")

      # Find source products (including inactive ones)
      paper_dinner = Product.unscoped.find_by(slug: "paper-dinner-napkins")
      premium_dinner = Product.unscoped.find_by(slug: "premium-dinner-napkins")
      airlaid_dinner = Product.find_by(slug: "airlaid-napkins")
      airlaid_pocket = Product.find_by(slug: "airlaid-pocket-napkins")

      # Create consolidated product
      consolidated = Product.find_or_create_by!(slug: "dinner-napkins") do |p|
        p.name = "Dinner Napkins"
        p.category = napkins_category
        p.description_short = "Quality dinner napkins from paper to luxury airlaid."
        p.description_standard = "Elegant dinner napkins for restaurants, hotels, and catering. Available in paper 2-ply for everyday use, paper 3-ply for special occasions, or luxurious airlaid for fine dining."
        p.description_detailed = "Our dinner napkin collection caters to every dining experience. Paper 2-ply napkins offer reliable quality at an economical price point. Paper 3-ply provides extra absorbency and a more substantial feel. Airlaid napkins deliver the look and feel of linen without the laundry costs - perfect for fine dining and special events. Airlaid pocket napkins add an elegant presentation touch, allowing cutlery to be neatly wrapped. All napkins are 40cm for proper dinner service."
        p.active = true
        p.featured = true
      end

      variants_data = []

      # Paper 2-ply variants
      if paper_dinner
        paper_dinner.variants.each do |v|
          colour = v.option_values["colour"]&.titleize || (v.sku.include?("BL") ? "Black" : "White")
          variants_data << {
            option_values: { "material" => "Paper 2-ply", "colour" => colour },
            source_variant: v
          }
        end
      end

      # Paper 3-ply variants (premium)
      if premium_dinner
        premium_dinner.variants.each do |v|
          colour = v.option_values["colour"]&.titleize || (v.sku.include?("BL") ? "Black" : "White")
          variants_data << {
            option_values: { "material" => "Paper 3-ply", "colour" => colour },
            source_variant: v
          }
        end
      end

      # Airlaid variants
      if airlaid_dinner
        airlaid_dinner.variants.each do |v|
          colour = v.option_values["colour"]&.titleize || (v.sku.include?("BL") ? "Black" : "White")
          variants_data << {
            option_values: { "material" => "Airlaid", "colour" => colour },
            source_variant: v
          }
        end
      end

      # Airlaid Pocket variant
      if airlaid_pocket
        airlaid_pocket.variants.each do |v|
          variants_data << {
            option_values: { "material" => "Airlaid Pocket", "colour" => "White" },
            source_variant: v
          }
        end
      end

      move_variants(consolidated, variants_data)
      deactivate_products(paper_dinner, premium_dinner, airlaid_dinner, airlaid_pocket)
      puts "   Moved #{variants_data.size} variants to Dinner Napkins"
    end

    # ===========================================
    # STRAWS
    # ===========================================
    def consolidate_straws
      puts "\n📦 Consolidating Straws..."

      straws_category = Category.find_by!(slug: "straws")

      # Find source products
      paper_straws = Product.find_by(slug: "paper-straws")
      bio_fibre = Product.find_by(slug: "bio-fibre-straws")
      bamboo_pulp = Product.find_by(slug: "bamboo-pulp-straws")

      # Create consolidated product
      consolidated = Product.find_or_create_by!(slug: "straws") do |p|
        p.name = "Eco-Friendly Straws"
        p.category = straws_category
        p.description_short = "Sustainable straws in paper, bio fibre, or bamboo pulp."
        p.description_standard = "Plastic-free drinking straws for eco-conscious venues. Choose from classic paper straws, premium bio fibre, or 100% natural bamboo pulp options in various sizes."
        p.description_detailed = "Our range of eco-friendly straws helps your venue go plastic-free without compromising on quality. Paper straws are the classic choice - affordable and widely recognised by customers. Bio fibre straws offer enhanced durability with a natural beige colour that sets them apart. Bamboo pulp straws are our most sustainable option, made from rapidly renewable bamboo and fully home-compostable. Available in multiple sizes: 6x140mm for cocktails, 6x200mm standard, 8x200mm jumbo, and 10x200mm for smoothies and milkshakes."
        p.active = true
        p.featured = true
      end

      variants_data = []

      # Paper straw variants
      if paper_straws
        paper_straws.variants.each do |v|
          size = v.option_values["size"] || "6x200mm"
          colour = v.option_values["colour"]&.titleize
          variants_data << {
            option_values: { "material" => "Paper", "size" => size, "colour" => colour },
            source_variant: v
          }
        end
      end

      # Bio Fibre variants
      if bio_fibre
        bio_fibre.variants.each do |v|
          size = v.option_values["size"] || "6x200mm"
          colour = v.option_values["colour"] == "natural-beige" ? "Natural" : "Black"
          variants_data << {
            option_values: { "material" => "Bio Fibre", "size" => size, "colour" => colour },
            source_variant: v
          }
        end
      end

      # Bamboo Pulp variants
      if bamboo_pulp
        bamboo_pulp.variants.each do |v|
          size = v.option_values["size"] || "6x200mm"
          variants_data << {
            option_values: { "material" => "Bamboo", "size" => size, "colour" => "Natural" },
            source_variant: v
          }
        end
      end

      move_variants(consolidated, variants_data)
      deactivate_products(paper_straws, bio_fibre, bamboo_pulp)
      puts "   Moved #{variants_data.size} variants to Straws"
    end

    # ===========================================
    # WOODEN CUTLERY
    # ===========================================
    def consolidate_wooden_cutlery
      puts "\n📦 Consolidating Wooden Cutlery..."

      extras_category = Category.find_by!(slug: "takeaway-extras")

      # Find source products
      forks = Product.find_by(slug: "wooden-forks")
      knives = Product.find_by(slug: "wooden-knives")
      spoons = Product.find_by(slug: "wooden-spoons")
      kits = Product.find_by(slug: "wooden-cutlery-kits")

      # Create consolidated product
      consolidated = Product.find_or_create_by!(slug: "wooden-cutlery") do |p|
        p.name = "Wooden Cutlery"
        p.category = extras_category
        p.description_short = "Disposable wooden forks, knives, spoons, and kits."
        p.description_standard = "Sustainable wooden cutlery for takeaway and events. Individual forks, knives, and spoons, or convenient cutlery kits with napkin included."
        p.description_detailed = "Our wooden cutlery range offers a plastic-free alternative for takeaway food service. Made from birch wood, these utensils are sturdy enough for hot food and fully compostable after use. Choose individual forks, knives, or spoons for flexibility, or our popular cutlery kits that include a fork, knife, and napkin wrapped together for convenience. All items are 160mm in length - the standard size for food service."
        p.active = true
        p.featured = false
      end

      variants_data = []

      # Fork variant
      if forks
        forks.variants.each do |v|
          variants_data << { option_values: { "type" => "Fork" }, source_variant: v }
        end
      end

      # Knife variant
      if knives
        knives.variants.each do |v|
          variants_data << { option_values: { "type" => "Knife" }, source_variant: v }
        end
      end

      # Spoon variant
      if spoons
        spoons.variants.each do |v|
          variants_data << { option_values: { "type" => "Spoon" }, source_variant: v }
        end
      end

      # Cutlery Kit variant
      if kits
        kits.variants.each do |v|
          variants_data << { option_values: { "type" => "Cutlery Kit" }, source_variant: v }
        end
      end

      move_variants(consolidated, variants_data)
      deactivate_products(forks, knives, spoons, kits)
      puts "   Moved #{variants_data.size} variants to Wooden Cutlery"
    end

    # ===========================================
    # HELPER: Move variants to consolidated product
    # ===========================================
    def move_variants(product, variants_data)
      variants_data.each_with_index do |data, index|
        variant = data[:source_variant]
        next unless variant

        # Move variant to new product and update option_values
        variant.update!(
          product: product,
          option_values: data[:option_values],
          position: index + 1,
          active: true
        )
      end
    end

    # ===========================================
    # HELPER: Deactivate old source products
    # ===========================================
    def deactivate_products(*products)
      products.compact.each do |product|
        product.reload
        next if product.variants.any? # Skip if still has variants

        product.update!(active: false)
        puts "   Deactivated: #{product.slug}"
      end
    end
  end
end

# Run the consolidation
ProductConsolidation.run!
