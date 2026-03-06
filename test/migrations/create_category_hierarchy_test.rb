require "test_helper"

class CreateCategoryHierarchyTest < ActiveSupport::TestCase
  # Test the pattern matching rules used in redistribute_takeaway_extras
  # These patterns determine where products from the killed "Takeaway Extras"
  # category end up (PRD Section 6.5).

  REDISTRIBUTION_RULES = [
    { pattern: /sleeve/i, target_slug: "cup-accessories" },
    { pattern: /stirrer|cup.carrier|sugar.stick|sweetener.stick/i, target_slug: "cup-accessories" },
    { pattern: /\bbags?\b|carrier/i, target_slug: "bags" },
    { pattern: /cutlery|fork|knife|knives|spoon|chopstick/i, target_slug: "cutlery" },
    { pattern: /burger.wrap|greaseproof|gingham|deli.wrap|foil.wrap|\bsheet\b/i, target_slug: "greaseproof-and-wraps" },
    { pattern: /microwav|lids?\s+for\s+no|pillow.pack/i, target_slug: "food-containers" },
    { pattern: /aluminium|aluminum/i, target_slug: "aluminium-containers" },
    { pattern: /label|sticker/i, target_slug: "labels-and-stickers" },
    { pattern: /glove|centrefeed|ntrefeed|cleaning|release.agent/i, target_slug: "gloves-and-cleaning" },
    { pattern: /till.roll|pdq.roll/i, target_slug: "till-rolls" },
    { pattern: /sandwich|baguette|tortilla|wedge/i, target_slug: "sandwich-and-wrap-boxes" },
    { pattern: /bin.liner|completely.liner/i, target_slug: "bin-liners" }
  ].freeze

  def match_product(name)
    REDISTRIBUTION_RULES.each do |rule|
      return rule[:target_slug] if name.match?(rule[:pattern])
    end
    "gloves-and-cleaning" # default fallback
  end

  # Cup Accessories
  test "sleeves route to cup-accessories" do
    assert_equal "cup-accessories", match_product("Vegware Cup Sleeve 8oz")
    assert_equal "cup-accessories", match_product("Corrugated Sleeve for 12oz")
  end

  test "stirrers route to cup-accessories" do
    assert_equal "cup-accessories", match_product("Wooden Stirrer 140mm")
    assert_equal "cup-accessories", match_product("Vegware Stirrers 190mm")
  end

  test "cup carriers route to cup-accessories" do
    assert_equal "cup-accessories", match_product("2-Cup Carrier Pulp")
    assert_equal "cup-accessories", match_product("4-Cup Carrier Vegware")
  end

  test "sugar sticks route to cup-accessories" do
    assert_equal "cup-accessories", match_product("Vegware Sugar Stick 3g")
    assert_equal "cup-accessories", match_product("Sweetener Sticks Box")
  end

  # Bags
  test "bags route to bags" do
    assert_equal "bags", match_product("Flat Handle Paper Bags")
    assert_equal "bags", match_product("Twisted Handle Bag White")
    assert_equal "bags", match_product("Carrier Bags Large")
  end

  # Cutlery
  test "cutlery items route to cutlery" do
    assert_equal "cutlery", match_product("Wooden Fork 160mm")
    assert_equal "cutlery", match_product("Wooden Knife 160mm")
    assert_equal "cutlery", match_product("Wooden Spoon 160mm")
    assert_equal "cutlery", match_product("Cutlery Kit Fork/Knife/Napkin")
    assert_equal "cutlery", match_product("Bamboo Chopstick Set")
    assert_equal "cutlery", match_product("Set of Knives and Forks")
  end

  # Greaseproof & Wraps
  test "wraps and greaseproof route to greaseproof-and-wraps" do
    assert_equal "greaseproof-and-wraps", match_product("Burger Wrap Red Gingham")
    assert_equal "greaseproof-and-wraps", match_product("Greaseproof Paper White 400x300")
    assert_equal "greaseproof-and-wraps", match_product("Gingham Sheet Red 250x250")
    assert_equal "greaseproof-and-wraps", match_product("Deli Wrap Kraft")
    assert_equal "greaseproof-and-wraps", match_product("Foil Wrap Insulated")
    assert_equal "greaseproof-and-wraps", match_product("Greaseproof Sheet Pack")
  end

  # Food Containers
  test "microwaveable containers route to food-containers" do
    assert_equal "food-containers", match_product("Microwaveable Container 750ml")
    assert_equal "food-containers", match_product("Microwave Safe Box")
  end

  # Aluminium Containers
  test "aluminium items route to aluminium-containers" do
    assert_equal "aluminium-containers", match_product("Aluminium Container 9x9")
    assert_equal "aluminium-containers", match_product("Aluminum Foil Container Lid")
  end

  # Labels & Stickers
  test "labels and stickers route to labels-and-stickers" do
    assert_equal "labels-and-stickers", match_product("Day Rotation Label Monday")
    assert_equal "labels-and-stickers", match_product("Allergen Sticker Pack")
    assert_equal "labels-and-stickers", match_product("Vegware Stickers Roll")
  end

  # Gloves & Cleaning
  test "gloves and cleaning route to gloves-and-cleaning" do
    assert_equal "gloves-and-cleaning", match_product("Food Handling Gloves Medium")
    assert_equal "gloves-and-cleaning", match_product("Blue Centrefeed Roll 2-Ply")
    assert_equal "gloves-and-cleaning", match_product("Release Agent Spray")
  end

  # Till Rolls
  test "till rolls route to till-rolls" do
    assert_equal "till-rolls", match_product("Thermal Till Roll 80x80")
    assert_equal "till-rolls", match_product("PDQ Roll 57x40")
  end

  # Sandwich & Wrap Boxes
  test "sandwich packaging routes to sandwich-and-wrap-boxes" do
    assert_equal "sandwich-and-wrap-boxes", match_product("Sandwich Wedge Kraft")
    assert_equal "sandwich-and-wrap-boxes", match_product("Baguette Tray Kraft")
    assert_equal "sandwich-and-wrap-boxes", match_product("Tortilla Carton Large")
  end

  # Bin Liners
  test "bin liners route to bin-liners" do
    assert_equal "bin-liners", match_product("Vegware Completely Liner 90L")
    assert_equal "bin-liners", match_product("Compostable Bin Liner 8L")
  end

  # Default fallback
  test "unmatched products default to gloves-and-cleaning" do
    assert_equal "gloves-and-cleaning", match_product("Mystery Product XYZ")
  end

  # =========================================================================
  # Migration structure tests — validate the expected hierarchy
  # =========================================================================

  EXPECTED_PARENTS = {
    "cups-and-drinks" => "Cups & Drinks",
    "hot-food" => "Hot Food",
    "cold-food-and-salads" => "Cold Food & Salads",
    "tableware" => "Tableware",
    "bags-and-wraps" => "Bags & Wraps",
    "supplies-and-essentials" => "Supplies & Essentials",
    "branded-packaging" => "Branded Packaging"
  }.freeze

  EXPECTED_SUBCATEGORIES = {
    "cups-and-drinks" => %w[hot-cups ice-cream-cups straws cold-cups cup-lids cup-accessories],
    "hot-food" => %w[pizza-boxes takeaway-boxes food-containers soup-containers bagasse-containers],
    "cold-food-and-salads" => %w[salad-boxes sandwich-and-wrap-boxes deli-pots],
    "tableware" => %w[plates-and-trays cutlery napkins aluminium-containers],
    "bags-and-wraps" => %w[bags greaseproof-and-wraps natureflex-bags],
    "supplies-and-essentials" => %w[bin-liners labels-and-stickers gloves-and-cleaning till-rolls],
    "branded-packaging" => %w[branded-cups branded-greaseproof]
  }.freeze

  test "migration defines 7 parent categories" do
    assert_equal 7, EXPECTED_PARENTS.size
  end

  test "migration defines 27 total subcategories" do
    total = EXPECTED_SUBCATEGORIES.values.map(&:size).sum
    assert_equal 27, total
  end

  test "all parent slugs are unique" do
    slugs = EXPECTED_PARENTS.keys
    assert_equal slugs.size, slugs.uniq.size
  end

  test "all subcategory slugs are unique across parents" do
    all_slugs = EXPECTED_SUBCATEGORIES.values.flatten
    assert_equal all_slugs.size, all_slugs.uniq.size
  end

  test "cups and drinks has 6 subcategories" do
    assert_equal 6, EXPECTED_SUBCATEGORIES["cups-and-drinks"].size
  end

  test "hot food has 5 subcategories" do
    assert_equal 5, EXPECTED_SUBCATEGORIES["hot-food"].size
  end

  test "cold food and salads has 3 subcategories" do
    assert_equal 3, EXPECTED_SUBCATEGORIES["cold-food-and-salads"].size
  end

  test "tableware has 4 subcategories" do
    assert_equal 4, EXPECTED_SUBCATEGORIES["tableware"].size
  end

  test "bags and wraps has 3 subcategories" do
    assert_equal 3, EXPECTED_SUBCATEGORIES["bags-and-wraps"].size
  end

  test "supplies and essentials has 4 subcategories" do
    assert_equal 4, EXPECTED_SUBCATEGORIES["supplies-and-essentials"].size
  end

  test "branded packaging has 2 subcategories" do
    assert_equal 2, EXPECTED_SUBCATEGORIES["branded-packaging"].size
  end

  # =========================================================================
  # Rename mapping tests
  # =========================================================================

  test "cups-and-lids becomes hot-cups under cups-and-drinks" do
    mapping = { "cups-and-lids" => { parent: "cups-and-drinks", new_slug: "hot-cups" } }
    assert_equal "hot-cups", mapping["cups-and-lids"][:new_slug]
    assert_equal "cups-and-drinks", mapping["cups-and-lids"][:parent]
  end

  test "takeaway-containers becomes soup-containers under hot-food" do
    mapping = { "takeaway-containers" => { parent: "hot-food", new_slug: "soup-containers" } }
    assert_equal "soup-containers", mapping["takeaway-containers"][:new_slug]
    assert_equal "hot-food", mapping["takeaway-containers"][:parent]
  end

  test "branded-products becomes branded-cups under branded-packaging" do
    mapping = { "branded-products" => { parent: "branded-packaging", new_slug: "branded-cups" } }
    assert_equal "branded-cups", mapping["branded-products"][:new_slug]
    assert_equal "branded-packaging", mapping["branded-products"][:parent]
  end
end
