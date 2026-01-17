namespace :collections do
  desc "Create default collections and sample packs"
  task seed: :environment do
    # Helper to find products by partial match across name, size, colour, material
    def find_products(*terms)
      # Search across multiple columns that make up the generated_title
      conditions = terms.map { "(name ILIKE ? OR size ILIKE ? OR colour ILIKE ? OR material ILIKE ?)" }
      values = terms.flat_map { |t| Array.new(4, "%#{t}%") }
      Product.active.catalog_products.where(conditions.join(" OR "), *values)
    end

    # Helper to find products by category slug
    def products_in_category(slug)
      category = Category.find_by(slug: slug)
      return Product.none unless category
      Product.active.catalog_products.where(category: category)
    end

    puts "Creating collections..."
    puts

    # =========================================================================
    # INDUSTRY-BASED COLLECTIONS (appear on /collections)
    # Based on competitive analysis of BrandYour.co collections
    # =========================================================================

    # 1. Coffee Shops
    coffee_shop = Collection.find_or_initialize_by(slug: "coffee-shops")
    coffee_shop.assign_attributes(
      name: "Coffee Shops",
      description: "Everything you need to serve hot drinks - from single and double wall cups to matching lids, stirrers, and carriers. Perfect for cafés, coffee shops, and mobile coffee vendors.",
      meta_title: "Coffee Shop Supplies | Eco-Friendly Cups & Lids | Afida",
      meta_description: "Complete range of eco-friendly coffee shop supplies including paper cups, sip lids, wooden stirrers, and cup carriers. Sustainable options for your café.",
      featured: true,
      sample_pack: false
    )
    if coffee_shop.new_record? || coffee_shop.products.empty?
      coffee_shop.save!
      coffee_shop.collection_items.destroy_all
      # Coffee cups (single, double, ripple wall), sip lids, stirrers, carriers
      coffee_products = find_products("Coffee Cup", "Sip Lid", "Stirrer", "Cup Carrier")
      coffee_products.each { |p| coffee_shop.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{coffee_shop.name} with #{coffee_shop.products.count} products"
    else
      puts "○ Exists: #{coffee_shop.name} (#{coffee_shop.products.count} products)"
    end

    # 2. Bakeries
    bakery = Collection.find_or_initialize_by(slug: "bakeries")
    bakery.assign_attributes(
      name: "Bakeries",
      description: "Packaging essentials for bakeries and pastry shops. From coffee cups for your morning rush to bags for takeaway treats.",
      meta_title: "Bakery Supplies | Eco-Friendly Packaging | Afida",
      meta_description: "Eco-friendly bakery packaging including paper cups, takeaway bags, and napkins. Sustainable solutions for bakeries and pastry shops.",
      featured: true,
      sample_pack: false
    )
    if bakery.new_record? || bakery.products.empty?
      bakery.save!
      bakery.collection_items.destroy_all
      # Coffee cups, bags, napkins
      bakery_products = find_products("Coffee Cup", "Bag", "Napkin")
      bakery_products.each { |p| bakery.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{bakery.name} with #{bakery.products.count} products"
    else
      puts "○ Exists: #{bakery.name} (#{bakery.products.count} products)"
    end

    # 3. Sweet Treats (Desserts/Ice Cream)
    sweet_treats = Collection.find_or_initialize_by(slug: "sweet-treats")
    sweet_treats.assign_attributes(
      name: "Sweet Treats",
      description: "Colourful cups and accessories for serving frozen treats and desserts. Eye-catching designs that customers love.",
      meta_title: "Ice Cream & Dessert Supplies | Afida",
      meta_description: "Eco-friendly ice cream cups, wooden spoons, and dessert packaging. Perfect for gelato shops, ice cream parlours, and dessert bars.",
      featured: true,
      sample_pack: false
    )
    if sweet_treats.new_record? || sweet_treats.products.empty?
      sweet_treats.save!
      sweet_treats.collection_items.destroy_all
      # Ice cream cups, wooden spoons, napkins
      sweet_products = find_products("Ice Cream", "Wooden Spoon")
      napkins = find_products("Cocktail Napkin")
      (sweet_products + napkins).uniq.each { |p| sweet_treats.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{sweet_treats.name} with #{sweet_treats.products.count} products"
    else
      puts "○ Exists: #{sweet_treats.name} (#{sweet_treats.products.count} products)"
    end

    # 4. Restaurants
    restaurant = Collection.find_or_initialize_by(slug: "restaurants")
    restaurant.assign_attributes(
      name: "Restaurants",
      description: "Professional takeaway packaging for restaurants. Containers, napkins, and accessories to keep food fresh and presentable.",
      meta_title: "Restaurant Takeaway Supplies | Eco-Friendly Packaging | Afida",
      meta_description: "Eco-friendly takeaway containers, napkins, and packaging for restaurants. Sustainable solutions for food service.",
      featured: true,
      sample_pack: false
    )
    if restaurant.new_record? || restaurant.products.empty?
      restaurant.save!
      restaurant.collection_items.destroy_all
      # Napkins, bags, takeaway containers, cutlery
      restaurant_products = find_products("Napkin", "Bag", "Takeaway", "Kraft Bowl", "Cutlery", "Fork", "Knife", "Spoon")
      restaurant_products.reject { |p| p.name.include?("Ice Cream") }.each { |p| restaurant.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{restaurant.name} with #{restaurant.products.count} products"
    else
      puts "○ Exists: #{restaurant.name} (#{restaurant.products.count} products)"
    end

    # 5. Takeaway
    takeaway = Collection.find_or_initialize_by(slug: "takeaway")
    takeaway.assign_attributes(
      name: "Takeaway",
      description: "Complete takeaway packaging solutions. From pizza boxes and food containers to bags and cutlery - everything for delivery and collection orders.",
      meta_title: "Takeaway Packaging | Boxes, Bags & Containers | Afida",
      meta_description: "Eco-friendly takeaway packaging including pizza boxes, food containers, kraft bags, and disposable cutlery. Sustainable solutions for takeaway businesses.",
      featured: true,
      sample_pack: false
    )
    if takeaway.new_record? || takeaway.products.empty?
      takeaway.save!
      takeaway.collection_items.destroy_all
      # Pizza boxes, takeaway boxes, soup containers, bowls, bags, cutlery
      takeaway_products = find_products("Pizza Box", "Takeaway Box", "Soup Container", "Kraft Bowl", "Bag", "Cutlery", "Fork", "Knife", "Spoon")
      # Also add lids for containers
      takeaway_products += find_products("Bowl Lid", "Soup").select { |p| p.name.include?("Lid") }
      takeaway_products.uniq.each { |p| takeaway.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{takeaway.name} with #{takeaway.products.count} products"
    else
      puts "○ Exists: #{takeaway.name} (#{takeaway.products.count} products)"
    end

    # 6. Smoothie & Juice Bars (NEW - requested by user)
    smoothie = Collection.find_or_initialize_by(slug: "smoothie-juice-bars")
    smoothie.assign_attributes(
      name: "Smoothie & Juice Bars",
      description: "Crystal-clear cups, dome and flat lids, and eco-friendly straws for smoothies, juices, and cold drinks. Perfect for juice bars, smoothie shops, and health food outlets.",
      meta_title: "Smoothie & Juice Bar Supplies | Clear Cups & Straws | Afida",
      meta_description: "Eco-friendly smoothie cups, dome lids, flat lids, and paper straws. Complete range for juice bars and smoothie shops.",
      featured: true,
      sample_pack: false
    )
    if smoothie.new_record? || smoothie.products.empty?
      smoothie.save!
      smoothie.collection_items.destroy_all
      # Smoothie cups, dome lids, flat lids, straws
      smoothie_products = find_products("Smoothie Cup", "Smoothie Dome Lid", "Smoothie Flat Lid", "Straw")
      smoothie_products.each { |p| smoothie.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{smoothie.name} with #{smoothie.products.count} products"
    else
      puts "○ Exists: #{smoothie.name} (#{smoothie.products.count} products)"
    end

    # 7. Health + Fitness
    health = Collection.find_or_initialize_by(slug: "health-fitness")
    health.assign_attributes(
      name: "Health + Fitness",
      description: "Clear cups and lids perfect for protein shakes, smoothies, and healthy drinks. Ideal for gyms, health clubs, and wellness centres.",
      meta_title: "Health & Fitness Supplies | Clear Cups & Lids | Afida",
      meta_description: "Eco-friendly clear cups and lids for gyms, health clubs, and fitness centres. Perfect for protein shakes and healthy drinks.",
      featured: true,
      sample_pack: false
    )
    if health.new_record? || health.products.empty?
      health.save!
      health.collection_items.destroy_all
      # Clear/smoothie cups, lids, straws, napkins
      health_products = find_products("Smoothie Cup", "Smoothie Dome Lid", "Smoothie Flat Lid", "Straw", "Napkin")
      health_products.each { |p| health.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{health.name} with #{health.products.count} products"
    else
      puts "○ Exists: #{health.name} (#{health.products.count} products)"
    end

    # 8. Pubs + Bars
    pubs = Collection.find_or_initialize_by(slug: "pubs-bars")
    pubs.assign_attributes(
      name: "Pubs + Bars",
      description: "Essential supplies for pubs, bars, and nightlife venues. Napkins, straws, and accessories for a great customer experience.",
      meta_title: "Pub & Bar Supplies | Napkins & Straws | Afida",
      meta_description: "Eco-friendly napkins, straws, and accessories for pubs and bars. Sustainable supplies for the hospitality industry.",
      featured: true,
      sample_pack: false
    )
    if pubs.new_record? || pubs.products.empty?
      pubs.save!
      pubs.collection_items.destroy_all
      # Napkins, straws
      pubs_products = find_products("Napkin", "Straw")
      pubs_products.each { |p| pubs.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{pubs.name} with #{pubs.products.count} products"
    else
      puts "○ Exists: #{pubs.name} (#{pubs.products.count} products)"
    end

    # 9. Hotels
    hotels = Collection.find_or_initialize_by(slug: "hotels")
    hotels.assign_attributes(
      name: "Hotels",
      description: "Premium supplies for hotel restaurants, room service, and conference facilities. Professional quality for discerning guests.",
      meta_title: "Hotel Supplies | Premium Catering Packaging | Afida",
      meta_description: "Eco-friendly hotel supplies including coffee cups, napkins, and takeaway packaging. Premium quality for hospitality professionals.",
      featured: true,
      sample_pack: false
    )
    if hotels.new_record? || hotels.products.empty?
      hotels.save!
      hotels.collection_items.destroy_all
      # Coffee cups, napkins, stirrers, bags
      hotel_products = find_products("Coffee Cup", "Sip Lid", "Napkin", "Stirrer", "Bag")
      hotel_products.each { |p| hotels.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{hotels.name} with #{hotels.products.count} products"
    else
      puts "○ Exists: #{hotels.name} (#{hotels.products.count} products)"
    end

    # 10. Eco Essentials (keeping as requested)
    eco = Collection.find_or_initialize_by(slug: "eco-essentials")
    eco.assign_attributes(
      name: "Eco Essentials",
      description: "Our most sustainable products - made from bamboo, bagasse, and other renewable materials. The greenest choice for environmentally conscious businesses.",
      meta_title: "Most Sustainable Products | Eco Essentials | Afida",
      meta_description: "Our greenest products made from bamboo, bagasse, and compostable materials. The most sustainable choice for your business.",
      featured: true,
      sample_pack: false
    )
    if eco.new_record? || eco.products.empty?
      eco.save!
      eco.collection_items.destroy_all
      eco_products = find_products("Bamboo", "Bagasse", "Compostable", "Wood", "Bio Fibre")
      eco_products.each { |p| eco.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{eco.name} with #{eco.products.count} products"
    else
      puts "○ Exists: #{eco.name} (#{eco.products.count} products)"
    end

    # =========================================================================
    # SAMPLE PACKS (appear on /samples/:slug)
    # =========================================================================
    # Using short slugs for clean URLs: /samples/coffee-shop, /samples/bakery, etc.

    # 11. Coffee Shop Sample Pack
    coffee_sample = Collection.find_or_initialize_by(slug: "coffee-shop")
    coffee_sample.assign_attributes(
      name: "Coffee Shop Sample Pack",
      description: "Try our most popular coffee shop products. Includes a selection of cup sizes, matching lids, and accessories.",
      featured: false,
      sample_pack: true
    )
    if coffee_sample.new_record? || coffee_sample.products.empty?
      coffee_sample.save!
      coffee_sample.collection_items.destroy_all
      # Use SKU-based lookup for precision
      sample_ids = [
        Product.find_by(sku: "8WSW")&.id,     # 8oz Single Wall Coffee Cup
        Product.find_by(sku: "8-DWC-W")&.id,  # 8oz Double Wall Coffee Cup (White)
        Product.find_by(sku: "8KRDW")&.id,    # 8oz Ripple Wall Coffee Cup (Kraft)
        Product.find_by(sku: "8BL-PC")&.id    # 8oz Bagasse Sip Lid
      ].compact
      sample_products = Product.active.catalog_products.sample_eligible.where(id: sample_ids)
      sample_products.each { |p| coffee_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{coffee_sample.name} with #{coffee_sample.products.count} products"
    else
      puts "○ Exists: #{coffee_sample.name} (#{coffee_sample.products.count} products)"
    end

    # 12. Restaurant Sample Pack
    restaurant_sample = Collection.find_or_initialize_by(slug: "restaurant")
    restaurant_sample.assign_attributes(
      name: "Restaurant Sample Pack",
      description: "Sample our takeaway containers and packaging. Test sizes and quality before ordering in bulk.",
      featured: false,
      sample_pack: true
    )
    if restaurant_sample.new_record? || restaurant_sample.products.empty?
      restaurant_sample.save!
      restaurant_sample.collection_items.destroy_all
      rest_sample_ids = [
        find_products("500ml", "Rectangular").first&.id,
        find_products("1000ml", "Rectangular").first&.id,
        find_products("Takeaway Box").first&.id,
        find_products("Soup Container").where.not("name ILIKE ?", "%Lid%").first&.id
      ].compact
      rest_sample_products = Product.active.catalog_products.sample_eligible.where(id: rest_sample_ids)
      rest_sample_products.each { |p| restaurant_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{restaurant_sample.name} with #{restaurant_sample.products.count} products"
    else
      puts "○ Exists: #{restaurant_sample.name} (#{restaurant_sample.products.count} products)"
    end

    # 13. Ice Cream & Dessert Sample Pack (mirrors Sweet Treats collection)
    ice_cream_sample = Collection.find_or_initialize_by(slug: "ice-cream")
    ice_cream_sample.assign_attributes(
      name: "Ice Cream & Dessert Sample Pack",
      description: "Try our colourful ice cream cups and eco-friendly wooden spoons. Perfect for gelato shops, dessert bars, and frozen yogurt outlets.",
      featured: false,
      sample_pack: true
    )
    if ice_cream_sample.new_record? || ice_cream_sample.products.empty?
      ice_cream_sample.save!
      ice_cream_sample.collection_items.destroy_all
      # Use SKU-based lookup for precision (ice cream cups have specific SKUs)
      ice_sample_ids = [
        Product.find_by(sku: "4PICC")&.id,   # 4oz Ice Cream Cup
        Product.find_by(sku: "6PICC")&.id,   # 6oz Ice Cream Cup
        Product.find_by(sku: "8PICC")&.id,   # 8oz Ice Cream Cup
        Product.find_by(sku: "WCSPN")&.id    # Wooden Spoon
      ].compact
      ice_sample_products = Product.active.catalog_products.sample_eligible.where(id: ice_sample_ids)
      ice_sample_products.each { |p| ice_cream_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{ice_cream_sample.name} with #{ice_cream_sample.products.count} products"
    else
      puts "○ Exists: #{ice_cream_sample.name} (#{ice_cream_sample.products.count} products)"
    end

    # 14. Bakery Sample Pack (mirrors Bakeries collection)
    bakery_sample = Collection.find_or_initialize_by(slug: "bakery")
    bakery_sample.assign_attributes(
      name: "Bakery Sample Pack",
      description: "Essential packaging for bakeries and pastry shops. Includes coffee cups for your morning rush and bags for takeaway treats.",
      featured: false,
      sample_pack: true
    )
    if bakery_sample.new_record? || bakery_sample.products.empty?
      bakery_sample.save!
      bakery_sample.collection_items.destroy_all
      bakery_sample_ids = [
        Product.find_by(sku: "8-DWC-W")&.id,  # 8oz Double Wall Coffee Cup (White)
        Product.find_by(sku: "8BL-PC")&.id,   # 8oz Bagasse Sip Lid
        Product.find_by(sku: "SKTB")&.id,     # Small Kraft Flat Handle Bag
        Product.find_by(sku: "AIRCNWH")&.id   # White Premium Airlaid Cocktail Napkins
      ].compact
      bakery_sample_products = Product.active.catalog_products.sample_eligible.where(id: bakery_sample_ids)
      bakery_sample_products.each { |p| bakery_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{bakery_sample.name} with #{bakery_sample.products.count} products"
    else
      puts "○ Exists: #{bakery_sample.name} (#{bakery_sample.products.count} products)"
    end

    # 15. Takeaway Sample Pack (mirrors Takeaway collection)
    takeaway_sample = Collection.find_or_initialize_by(slug: "takeaway-essentials")
    takeaway_sample.assign_attributes(
      name: "Takeaway Sample Pack",
      description: "Complete takeaway packaging essentials. Test our pizza boxes, food containers, and bags before ordering in bulk.",
      featured: false,
      sample_pack: true
    )
    if takeaway_sample.new_record? || takeaway_sample.products.empty?
      takeaway_sample.save!
      takeaway_sample.collection_items.destroy_all
      takeaway_sample_ids = [
        Product.find_by(sku: "9PIZBKR")&.id,  # 9 inch Kraft Pizza Box
        Product.find_by(sku: "NO1KDV")&.id,   # No.1 Kraft Takeaway Box
        Product.find_by(sku: "5MLREC")&.id,   # 500ml Rectangular Kraft Bowl
        Product.find_by(sku: "WFKPNK")&.id    # Wooden Cutlery Kit
      ].compact
      takeaway_sample_products = Product.active.catalog_products.sample_eligible.where(id: takeaway_sample_ids)
      takeaway_sample_products.each { |p| takeaway_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{takeaway_sample.name} with #{takeaway_sample.products.count} products"
    else
      puts "○ Exists: #{takeaway_sample.name} (#{takeaway_sample.products.count} products)"
    end

    # 16. Smoothie & Juice Bar Sample Pack (mirrors Smoothie & Juice Bars collection)
    smoothie_sample = Collection.find_or_initialize_by(slug: "smoothie-bar")
    smoothie_sample.assign_attributes(
      name: "Smoothie & Juice Bar Sample Pack",
      description: "Crystal-clear cups, lids, and eco-friendly straws for smoothies and juices. Perfect for juice bars and health food outlets.",
      featured: false,
      sample_pack: true
    )
    if smoothie_sample.new_record? || smoothie_sample.products.empty?
      smoothie_sample.save!
      smoothie_sample.collection_items.destroy_all
      smoothie_sample_ids = [
        Product.find_by(sku: "16RPTRC")&.id,  # 16oz Clear Smoothie Cup
        Product.find_by(sku: "20RPTDL")&.id,  # 16-20oz Dome Lid
        Product.find_by(sku: "BB-PULP-JUM")&.id, # 8mm Jumbo Bamboo Straw (for smoothies)
        Product.find_by(sku: "BB-PULP-20")&.id   # 6mm Bamboo Straw (for juices)
      ].compact
      smoothie_sample_products = Product.active.catalog_products.sample_eligible.where(id: smoothie_sample_ids)
      smoothie_sample_products.each { |p| smoothie_sample.collection_items.find_or_create_by!(product: p) }
      puts "✓ Created: #{smoothie_sample.name} with #{smoothie_sample.products.count} products"
    else
      puts "○ Exists: #{smoothie_sample.name} (#{smoothie_sample.products.count} products)"
    end

    # =========================================================================
    # CLEANUP: Remove old collections that are being replaced
    # =========================================================================
    old_slugs = %w[coffee-shop-essentials restaurant-supplies ice-cream-parlour]
    old_slugs.each do |slug|
      if (old_collection = Collection.find_by(slug: slug))
        old_collection.destroy
        puts "✗ Removed old collection: #{slug}"
      end
    end

    puts
    puts "=" * 50
    puts "SUMMARY"
    puts "=" * 50
    puts "Regular Collections: #{Collection.regular.count}"
    Collection.regular.by_position.each { |c| puts "  - #{c.name} (#{c.products.count} products)" }
    puts
    puts "Sample Packs: #{Collection.sample_packs.count}"
    Collection.sample_packs.by_position.each { |c| puts "  - #{c.name} (#{c.products.count} products)" }
    puts
    puts "View collections at: /collections"
    puts "View sample packs at: /samples"
  end

  desc "List all collections with their products"
  task list: :environment do
    puts "REGULAR COLLECTIONS"
    puts "=" * 50
    Collection.regular.by_position.each do |c|
      puts "\n#{c.name} (#{c.slug})"
      puts "  Featured: #{c.featured? ? 'Yes' : 'No'}"
      puts "  Products: #{c.products.count}"
      c.products.limit(5).each { |p| puts "    - #{p.generated_title}" }
      puts "    ..." if c.products.count > 5
    end

    puts "\n\nSAMPLE PACKS"
    puts "=" * 50
    Collection.sample_packs.by_position.each do |c|
      puts "\n#{c.name} (#{c.slug})"
      puts "  Products: #{c.products.count}"
      c.products.each { |p| puts "    - #{p.generated_title}" }
    end
  end

  desc "Clear all collections (use with caution)"
  task clear: :environment do
    print "This will delete ALL collections. Are you sure? (yes/no): "
    confirmation = $stdin.gets.chomp
    if confirmation == "yes"
      CollectionItem.delete_all
      Collection.delete_all
      puts "All collections cleared."
    else
      puts "Aborted."
    end
  end

  desc "Reset and reseed all collections"
  task reset: :environment do
    puts "Clearing existing collections..."
    CollectionItem.delete_all
    Collection.delete_all
    puts "Reseeding collections..."
    Rake::Task["collections:seed"].invoke
  end
end
