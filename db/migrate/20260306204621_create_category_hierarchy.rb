# Migration to create the category hierarchy per PRD Section 6.
#
# Creates 8 top-level parent categories, 27 subcategories, and reassigns
# all products from the old flat structure into the new hierarchy.
#
# This migration is reversible — `down` restores the flat structure.
class CreateCategoryHierarchy < ActiveRecord::Migration[8.1]
  def up
    # =========================================================================
    # Step 1: Create top-level parent categories
    # =========================================================================
    parents = {}
    parent_definitions = [
      { name: "Cups & Drinks",          slug: "cups-and-drinks",          position: 1 },
      { name: "Hot Food",               slug: "hot-food",                 position: 2 },
      { name: "Cold Food & Salads",     slug: "cold-food-and-salads",     position: 3 },
      { name: "Tableware",              slug: "tableware",                position: 4 },
      { name: "Bags & Wraps",           slug: "bags-and-wraps",           position: 5 },
      { name: "Supplies & Essentials",  slug: "supplies-and-essentials",  position: 6 }
    ]

    parent_definitions.each do |attrs|
      cat = Category.find_or_create_by!(slug: attrs[:slug]) do |c|
        c.name = attrs[:name]
        c.position = attrs[:position]
      end
      cat.update!(parent_id: nil, position: attrs[:position])
      parents[attrs[:slug]] = cat
    end

    # =========================================================================
    # Step 2: Map existing categories to their new parent + subcategory info
    # =========================================================================
    #
    # Format: { existing_slug => { parent: "parent-slug", new_slug: "new-slug" (optional), new_name: "Name" (optional) } }
    # If new_slug/new_name are nil, keep existing.
    #
    # Categories that become subcategories directly:
    existing_to_subcategory = {
      "cups-and-lids"       => { parent: "cups-and-drinks", new_slug: "hot-cups",       new_name: "Hot Cups" },
      "ice-cream-cups"      => { parent: "cups-and-drinks" },
      "straws"              => { parent: "cups-and-drinks" },
      "pizza-boxes"         => { parent: "hot-food" },
      "takeaway-boxes"      => { parent: "hot-food" },
      "food-containers"     => { parent: "hot-food" },
      "takeaway-containers" => { parent: "hot-food", new_slug: "soup-containers", new_name: "Soup Containers" },
      "bagasse-eco-range"   => { parent: "hot-food", new_slug: "bagasse-containers", new_name: "Bagasse Containers" },
      "plates-trays"        => { parent: "tableware", new_slug: "plates-and-trays", new_name: "Plates & Trays" },
      "cutlery"             => { parent: "tableware" },
      "napkins"             => { parent: "tableware" },
      "bags"                => { parent: "bags-and-wraps" }
    }

    # Reassign existing categories as subcategories
    position_counters = Hash.new(0)
    existing_to_subcategory.each do |old_slug, mapping|
      cat = Category.find_by(slug: old_slug)
      next unless cat

      parent = parents[mapping[:parent]]
      position_counters[mapping[:parent]] += 1

      updates = { parent_id: parent.id, position: position_counters[mapping[:parent]] }
      updates[:slug] = mapping[:new_slug] if mapping[:new_slug]
      updates[:name] = mapping[:new_name] if mapping[:new_name]
      cat.update_columns(updates)
    end

    # =========================================================================
    # Step 3: Create new subcategories that don't exist yet
    # =========================================================================
    new_subcategories = [
      # Cups & Drinks
      { parent: "cups-and-drinks", name: "Cold Cups",         slug: "cold-cups" },
      { parent: "cups-and-drinks", name: "Cup Lids",          slug: "cup-lids" },
      { parent: "cups-and-drinks", name: "Cup Accessories",   slug: "cup-accessories" },

      # Cold Food & Salads
      { parent: "cold-food-and-salads", name: "Salad Boxes",           slug: "salad-boxes" },
      { parent: "cold-food-and-salads", name: "Sandwich & Wrap Boxes", slug: "sandwich-and-wrap-boxes" },
      { parent: "cold-food-and-salads", name: "Deli Pots",             slug: "deli-pots" },

      # Tableware
      { parent: "tableware", name: "Aluminium Containers", slug: "aluminium-containers" },

      # Bags & Wraps
      { parent: "bags-and-wraps", name: "Greaseproof & Wraps", slug: "greaseproof-and-wraps" },
      { parent: "bags-and-wraps", name: "NatureFlex Bags",     slug: "natureflex-bags" },

      # Supplies & Essentials
      { parent: "supplies-and-essentials", name: "Bin Liners",         slug: "bin-liners" },
      { parent: "supplies-and-essentials", name: "Labels & Stickers",  slug: "labels-and-stickers" },
      { parent: "supplies-and-essentials", name: "Gloves & Cleaning",  slug: "gloves-and-cleaning" },
      { parent: "supplies-and-essentials", name: "Till Rolls",         slug: "till-rolls" }
    ]

    new_subcategories.each do |attrs|
      parent = parents[attrs[:parent]]
      position_counters[attrs[:parent]] += 1
      Category.find_or_create_by!(slug: attrs[:slug]) do |c|
        c.name = attrs[:name]
        c.parent_id = parent.id
        c.position = position_counters[attrs[:parent]]
      end
    end

    # =========================================================================
    # Step 4: Redistribute "Takeaway Extras" products
    # =========================================================================
    takeaway_extras = Category.find_by(slug: "takeaway-extras")
    if takeaway_extras
      redistribute_takeaway_extras(takeaway_extras)
      # Delete the empty category
      if takeaway_extras.products.count == 0
        takeaway_extras.destroy!
      else
        say "WARNING: #{takeaway_extras.products.count} products remain in Takeaway Extras"
      end
    end

    # =========================================================================
    # Step 5: Reset counter caches
    # =========================================================================
    Category.find_each do |cat|
      Category.reset_counters(cat.id, :products)
    end
  end

  def down
    # Reverse: flatten hierarchy back to original structure
    #
    # Restore renamed categories
    renames = {
      "hot-cups"           => { slug: "cups-and-lids",        name: "Cups & Lids" },
      "soup-containers"    => { slug: "takeaway-containers",   name: "Takeaway Containers" },
      "bagasse-containers" => { slug: "bagasse-eco-range",     name: "Bagasse Eco Range" },
      "plates-and-trays"   => { slug: "plates-trays",          name: "Plates & Trays" }
    }

    renames.each do |current_slug, original|
      cat = Category.find_by(slug: current_slug)
      cat&.update_columns(slug: original[:slug], name: original[:name])
    end

    # Move all subcategories back to top level
    Category.where.not(parent_id: nil).update_all(parent_id: nil)

    # Remove parent categories that were created (they have no products)
    %w[cups-and-drinks hot-food cold-food-and-salads tableware bags-and-wraps supplies-and-essentials].each do |slug|
      cat = Category.find_by(slug: slug)
      cat&.destroy! if cat&.products&.count == 0
    end

    # Recreate Takeaway Extras first so we have a destination for orphaned products
    takeaway_extras = Category.find_or_create_by!(slug: "takeaway-extras") do |c|
      c.name = "Takeaway Extras"
      c.position = 99
    end

    # Remove new subcategories that were created, moving any products to Takeaway Extras
    %w[cold-cups cup-lids cup-accessories salad-boxes sandwich-and-wrap-boxes deli-pots
       aluminium-containers greaseproof-and-wraps natureflex-bags
       bin-liners labels-and-stickers gloves-and-cleaning till-rolls].each do |slug|
      cat = Category.find_by(slug: slug)
      next unless cat
      cat.products.update_all(category_id: takeaway_extras.id) if cat.products.exists?
      cat.destroy!
    end

    # Reset counters
    Category.find_each do |cat|
      Category.reset_counters(cat.id, :products)
    end
  end

  private

  # Redistribute products from Takeaway Extras based on product name patterns
  # per PRD Section 6.5
  def redistribute_takeaway_extras(takeaway_extras)
    rules = [
      # Sleeves for cups -> Cup Accessories
      { pattern: /sleeve/i, target_slug: "cup-accessories" },
      # Stirrers, cup carriers, sweetener sticks -> Cup Accessories
      { pattern: /stirrer|cup.carrier|sugar.stick|sweetener.stick/i, target_slug: "cup-accessories" },
      # Bags (flat handle, twisted handle, carrier) -> Bags
      { pattern: /\bbags?\b|carrier/i, target_slug: "bags" },
      # Wooden cutlery -> Cutlery
      { pattern: /cutlery|fork|knife|knives|spoon|chopstick/i, target_slug: "cutlery" },
      # Burger wraps, greaseproof, deli wraps, foil wraps, sheets -> Greaseproof & Wraps
      { pattern: /burger.wrap|greaseproof|gingham|deli.wrap|foil.wrap|\bsheet\b/i, target_slug: "greaseproof-and-wraps" },
      # Lids for containers, microwaveable, pillow packs -> Food Containers
      { pattern: /microwav|lids?\s+for\s+no|pillow.pack/i, target_slug: "food-containers" },
      # Aluminium container lids -> Aluminium Containers
      { pattern: /aluminium|aluminum/i, target_slug: "aluminium-containers" },
      # Labels & stickers -> Labels & Stickers
      { pattern: /label|sticker/i, target_slug: "labels-and-stickers" },
      # Gloves, centrefeed (including typos), cleaning -> Gloves & Cleaning
      { pattern: /glove|centrefeed|ntrefeed|cleaning|release.agent/i, target_slug: "gloves-and-cleaning" },
      # Till rolls -> Till Rolls
      { pattern: /till.roll|pdq.roll/i, target_slug: "till-rolls" },
      # Sandwich packaging -> Sandwich & Wrap Boxes
      { pattern: /sandwich|baguette|tortilla|wedge/i, target_slug: "sandwich-and-wrap-boxes" },
      # Bin liners -> Bin Liners
      { pattern: /bin.liner|completely.liner/i, target_slug: "bin-liners" }
    ]

    # Build a lookup of target categories
    target_categories = {}
    rules.each do |rule|
      target_categories[rule[:target_slug]] ||= Category.find_by!(slug: rule[:target_slug])
    end

    # Process each product
    takeaway_extras.products.find_each do |product|
      matched = false
      rules.each do |rule|
        if product.name.match?(rule[:pattern])
          product.update_columns(category_id: target_categories[rule[:target_slug]].id)
          matched = true
          break
        end
      end

      unless matched
        # Default: move unmatched to Supplies & Essentials -> Gloves & Cleaning (misc ops)
        say "WARNING: No pattern match for '#{product.name}' (ID: #{product.id}) — defaulting to Gloves & Cleaning"
        product.update_columns(category_id: target_categories["gloves-and-cleaning"].id)
      end
    end
  end
end
