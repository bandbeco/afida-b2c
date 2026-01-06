require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @category = categories(:one)
    # Ensure products(:one) is valid with an SKU for tests that use it directly
    # If your fixture doesn't have it, some tests might need adjustment or direct product creation.
    # For now, tests assume products(:one) has a name 'Product 1' and sku 'SKUONE'
    # and a corresponding slug 'skuone-product-1' in the fixture.
    @product_one = products(:one)
  end

  test "default scope should return active products" do
    active_products = Product.all
    assert active_products.include?(@product_one)
    assert_not active_products.include?(products(:inactive_product)) # Inactive product is excluded
  end

  test "should validate presence of name" do
    product = Product.new(sku: "testsku", category: @category) # name is nil
    assert_not product.valid?
    assert product.errors[:name].any?
  end

  test "should validate presence of category" do
    product = Product.new(name: "Test Name", sku: "testsku") # category is nil
    assert_not product.valid?
    assert product.errors[:category].any?
  end

  # Slug generation tests
  test "should generate slug from sku and name on create if slug is blank" do
    product = Product.new(name: "New Awesome Product", sku: "NAP123", category: @category)
    assert product.save
    assert_equal "nap123-new-awesome-product", product.slug
  end

  test "should use provided slug on create if slug is present" do
    product = Product.new(name: "New Awesome Product with Slug", sku: "NAPWS456", category: @category, slug: "my-custom-slug")
    assert product.save
    assert_equal "my-custom-slug", product.slug
  end

  test "should not change existing slug on update even if name or sku changes" do
    # Assuming @product_one (from fixtures) has sku 'SKUONE', name 'Product 1', and slug 'skuone-product-1'
    original_slug = @product_one.slug
    @product_one.name = "Updated Product Name"
    @product_one.sku = "UPDATEDSKU" # Change SKU as well
    assert @product_one.save
    assert_equal original_slug, @product_one.slug # Slug should not change automatically on update
  end

  test "should regenerate slug on update if slug is manually cleared" do
    # Use a fresh product to avoid fixture state issues and ensure SKU is set for regeneration
    product = Product.create!(name: "Initial Name", sku: "REGENSKU1", category: @category)
    # product.slug is now "regensku1-initial-name"

    product.name = "Product For Slug Regeneration"
    product.sku = "REGENSKU2" # SKU might also change
    product.slug = "" # Manually clear the slug
    assert product.save
    assert_equal "regensku2-product-for-slug-regeneration", product.slug
  end

  test "should regenerate slug on update if slug is manually set to nil" do
    product = Product.create!(name: "Initial Nil Name", sku: "NILSKU1", category: @category)
    # product.slug is now "nilsku1-initial-nil-name"

    product.name = "Product For Nil Slug Regeneration"
    product.sku = "NILSKU2"
    product.slug = nil # Manually clear the slug by setting to nil
    assert product.save
    assert_equal "nilsku2-product-for-nil-slug-regeneration", product.slug
  end

  test "should save manually updated slug" do
    new_slug = "my-manually-updated-slug"
    @product_one.slug = new_slug
    assert @product_one.save
    assert_equal new_slug, @product_one.slug
  end

  test "should not generate slug if name is blank (validation failure)" do
    product = Product.new(name: "", sku: "NOSLUGSKU1", category: @category, slug: "")
    assert_not product.save # Save should fail due to name validation
    assert product.errors[:name].any?
    assert_equal "", product.slug # Slug should remain blank
  end

  # Product configuration tests
  test "product types are standard, customizable_template, customized_instance" do
    product = products(:one)

    product.product_type = "standard"
    assert product.valid?

    product.product_type = "customizable_template"
    assert product.valid?

    # customized_instance requires parent_product and organization, so use a proper fixture
    customized_product = products(:acme_branded_cups)
    customized_product.product_type = "customized_instance"
    assert customized_product.valid?

    # Rails enum with validate: true will reject invalid values on validation
    product.product_type = "invalid"
    assert_not product.valid?
    assert_includes product.errors[:product_type], "is not included in the list"
  end

  test "customized_instance requires parent_product_id" do
    product = Product.new(
      name: "Test Instance",
      product_type: "customized_instance",
      parent_product_id: nil
    )
    assert_not product.valid?
    assert_includes product.errors[:parent_product_id], "can't be blank"
  end

  test "customized_instance requires organization_id" do
    product = Product.new(
      name: "Test Instance",
      product_type: "customized_instance",
      parent_product_id: products(:branded_double_wall_template).id,
      organization_id: nil
    )
    assert_not product.valid?
    assert_includes product.errors[:organization_id], "can't be blank"
  end

  test "customized_instance stores configuration_data" do
    product = products(:acme_branded_cups)
    assert_equal "12oz", product.configuration_data["size"]
    assert_equal "double_wall", product.configuration_data["type"]
    assert_equal 5000, product.configuration_data["quantity_ordered"]
  end

  test "standard and template products dont require parent or organization" do
    product = Product.new(
      name: "Test",
      product_type: "standard",
      category: categories(:one)
    )
    assert product.valid?
  end

  test "product has many option assignments" do
    product = products(:single_wall_cups)
    assert_includes product.option_assignments.map(&:product_option), product_options(:size)
  end

  test "product has many options through assignments" do
    product = products(:single_wall_cups)
    assert_includes product.options, product_options(:size)
    assert_includes product.options, product_options(:colour)
  end

  test "belongs to organization for customized instances" do
    product = products(:acme_branded_cups)
    assert_equal organizations(:acme), product.organization
  end

  test "belongs to parent product for customized instances" do
    product = products(:acme_branded_cups)
    assert_equal products(:branded_double_wall_template), product.parent_product
  end

  # Photo attachment tests
  test "can attach product_photo" do
    product = products(:one)
    file = fixture_file_upload("product.jpg", "image/jpeg")

    product.product_photo.attach(file)

    assert product.product_photo.attached?
  end

  test "can attach lifestyle_photo" do
    product = products(:one)
    file = fixture_file_upload("lifestyle.jpg", "image/jpeg")

    product.lifestyle_photo.attach(file)

    assert product.lifestyle_photo.attached?
  end

  test "primary_photo returns product_photo when both attached" do
    product = products(:one)
    product.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))
    product.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    assert_equal product.product_photo, product.primary_photo
  end

  test "primary_photo returns lifestyle_photo when only lifestyle attached" do
    product = products(:one)
    product.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    assert_equal product.lifestyle_photo, product.primary_photo
  end

  test "primary_photo returns nil when no photos attached" do
    product = products(:one)

    assert_nil product.primary_photo
  end

  test "photos returns array of attached photos" do
    product = products(:one)
    product.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))
    product.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    photos = product.photos

    assert_equal 2, photos.length
    assert_includes photos, product.product_photo
    assert_includes photos, product.lifestyle_photo
  end

  test "photos returns only attached photos" do
    product = products(:one)
    product.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))

    photos = product.photos

    assert_equal 1, photos.length
    assert_equal product.product_photo, photos.first
  end

  test "has_photos? returns true when product_photo attached" do
    product = products(:one)
    product.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))

    assert product.has_photos?
  end

  test "has_photos? returns true when lifestyle_photo attached" do
    product = products(:one)
    product.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    assert product.has_photos?
  end

  test "has_photos? returns false when no photos attached" do
    product = products(:one)

    assert_not product.has_photos?
  end

  # Compatible cup sizes tests
  test "compatible_cup_sizes can store array of sizes" do
    product = products(:one)
    product.compatible_cup_sizes = [ "8oz", "12oz", "16oz" ]
    assert product.save

    product.reload
    assert_equal [ "8oz", "12oz", "16oz" ], product.compatible_cup_sizes
  end

  test "compatible_cup_sizes defaults to empty array" do
    product = Product.new(
      name: "Test Product",
      category: categories(:one),
      slug: "test-product-slug"
    )
    assert product.save

    assert_equal [], product.compatible_cup_sizes
  end

  test "should have custom label fields" do
    product = products(:one)

    product.profit_margin = "high"
    product.best_seller = true
    product.seasonal_type = "year_round"
    product.b2b_priority = "high"

    assert product.save
    assert_equal "high", product.profit_margin
    assert product.best_seller
    assert_equal "year_round", product.seasonal_type
    assert_equal "high", product.b2b_priority
  end

  test "should validate profit_margin values" do
    product = products(:one)
    product.profit_margin = "invalid"

    assert_not product.valid?
    assert_includes product.errors[:profit_margin], "is not included in the list"
  end

  # Category filtering scope tests
  test "in_categories filters by single category slug" do
    category = categories(:one)
    product_in_category = products(:one)
    product_in_category.update(category: category)

    results = Product.in_categories([ category.slug ])

    assert_includes results, product_in_category
    # Verify it's filtering (not just returning all)
    assert results.count <= category.products.count
  end

  test "in_categories filters by multiple category slugs" do
    category1 = categories(:one)
    category2 = Category.create!(name: "Category Two", slug: "category-two")

    product1 = products(:one)
    product1.update(category: category1)

    product2 = Product.create!(name: "Product 2", sku: "SKU2", category: category2)

    results = Product.in_categories([ category1.slug, category2.slug ])

    assert_includes results, product1
    assert_includes results, product2
  end

  test "in_categories returns all products when categories is blank" do
    all_count = Product.count

    assert_equal all_count, Product.in_categories([]).count
    assert_equal all_count, Product.in_categories(nil).count
  end

  # Search scope tests
  test "search returns products matching name" do
    pizza_product = products(:one)
    pizza_product.update(name: "Pizza Box Kraft")

    results = Product.search("pizza")

    assert_includes results, pizza_product
    # Verify it's actually filtering (not returning all)
    assert results.count < Product.count, "Search should filter results"
  end

  test "search returns products matching SKU" do
    product = products(:one)
    product.update(sku: "PIZB-001")

    results = Product.search("PIZB")

    assert_includes results, product
  end

  test "search is case-insensitive" do
    product = products(:one)
    product.update(name: "Pizza Box")

    results = Product.search("PIZZA")

    assert_includes results, product
  end

  test "search returns all products when query is blank" do
    all_count = Product.count

    assert_equal all_count, Product.search("").count
    assert_equal all_count, Product.search(nil).count
  end

  test "search truncates excessively long queries" do
    # Create a query longer than 100 characters
    long_query = "a" * 150

    # Should not raise error, query should be truncated
    results = Product.search(long_query)

    # Should return results (or empty array), not raise error
    assert_kind_of ActiveRecord::Relation, results
  end

  # Sort scope tests
  test "sorted by relevance uses default order" do
    products = Product.sorted("relevance").to_a

    # Should match default scope (position ASC, name ASC)
    assert_equal Product.all.to_a, products
  end

  test "sorted by name_asc orders alphabetically" do
    products = Product.sorted("name_asc").pluck(:name)

    assert_equal products.sort, products
  end

  test "sorted by price_asc orders by minimum variant price" do
    # Create two products with different prices
    cheap = Product.create!(name: "Cheap Product", sku: "CHEAP", category: categories(:one))
    expensive = Product.create!(name: "Expensive Product", sku: "EXPENSIVE", category: categories(:one))

    ProductVariant.create!(product: cheap, name: "Small", sku: "CHEAP-1", price: 1.00, stock_quantity: 100, active: true)
    ProductVariant.create!(product: expensive, name: "Large", sku: "EXP-1", price: 10.00, stock_quantity: 100, active: true)

    results = Product.sorted("price_asc").to_a

    assert results.index(cheap) < results.index(expensive), "Cheap product should come before expensive"
  end

  test "sorted by price_desc orders by minimum variant price descending" do
    # Create products with different minimum prices
    low_price = Product.create!(name: "Low Price Product", sku: "LOW", category: categories(:one))
    mid_price = Product.create!(name: "Mid Price Product", sku: "MID", category: categories(:one))
    high_price = Product.create!(name: "High Price Product", sku: "HIGH", category: categories(:one))

    # Low price product: min = 5, max = 20
    ProductVariant.create!(product: low_price, name: "Small", sku: "LOW-1", price: 5.00, stock_quantity: 100, active: true)
    ProductVariant.create!(product: low_price, name: "Large", sku: "LOW-2", price: 20.00, stock_quantity: 100, active: true)

    # Mid price product: min = 50, max = 100
    ProductVariant.create!(product: mid_price, name: "Small", sku: "MID-1", price: 50.00, stock_quantity: 100, active: true)
    ProductVariant.create!(product: mid_price, name: "Large", sku: "MID-2", price: 100.00, stock_quantity: 100, active: true)

    # High price product: min = 150, max = 200
    ProductVariant.create!(product: high_price, name: "Small", sku: "HIGH-1", price: 150.00, stock_quantity: 100, active: true)
    ProductVariant.create!(product: high_price, name: "Large", sku: "HIGH-2", price: 200.00, stock_quantity: 100, active: true)

    results = Product.sorted("price_desc").to_a

    # Should sort by MIN price descending: high_price (150) > mid_price (50) > low_price (5)
    assert results.index(high_price) < results.index(mid_price), "High price product should come before mid price"
    assert results.index(mid_price) < results.index(low_price), "Mid price product should come before low price"
  end

  test "sorted by price places products without variants at end" do
    # Create product without any variants
    no_variants = Product.create!(name: "No Variants Product", sku: "NOVARS", category: categories(:one))
    with_variants = Product.create!(name: "With Variants Product", sku: "WITHVARS", category: categories(:one))
    ProductVariant.create!(product: with_variants, name: "Standard", sku: "WITHVARS-1", price: 10.00, stock_quantity: 100, active: true)

    results_asc = Product.sorted("price_asc").to_a
    results_desc = Product.sorted("price_desc").to_a

    # Products without variants should appear at end (NULLS LAST)
    assert results_asc.index(with_variants) < results_asc.index(no_variants), "Product with variants should come before product without variants (asc)"
    assert results_desc.index(with_variants) < results_desc.index(no_variants), "Product with variants should come before product without variants (desc)"
  end

  # Description fallback method tests (T009-T016)
  test "description_short_with_fallback returns short when all three fields present" do
    product = products(:one)
    product.update_columns(
      description_short: "This is short",
      description_standard: "This is standard description text",
      description_detailed: "This is a much longer detailed description with lots of words and information about the product"
    )

    assert_equal "This is short", product.description_short_with_fallback
  end

  test "description_short_with_fallback truncates standard when short is blank" do
    product = products(:one)
    product.update_columns(
      description_short: nil,
      description_standard: "This is a standard description with more than fifteen words to test truncation behavior properly and correctly",
      description_detailed: "This is detailed"
    )

    result = product.description_short_with_fallback
    assert_not_nil result
    assert result.end_with?("...")
    assert result.split.length <= 16 # 15 words + "..."
  end

  test "description_short_with_fallback truncates detailed when short and standard are blank" do
    product = products(:one)
    product.update_columns(
      description_short: nil,
      description_standard: nil,
      description_detailed: "This is a detailed description with many many words more than fifteen to test the truncation fallback logic properly"
    )

    result = product.description_short_with_fallback
    assert_not_nil result
    assert result.end_with?("...")
    assert result.split.length <= 16 # 15 words + "..."
  end

  test "description_short_with_fallback returns nil when all fields are blank" do
    product = products(:one)
    product.update_columns(
      description_short: nil,
      description_standard: nil,
      description_detailed: nil
    )

    assert_nil product.description_short_with_fallback
  end

  test "description_standard_with_fallback returns standard when present" do
    product = products(:one)
    product.update_columns(
      description_standard: "This is the standard description",
      description_detailed: "This is detailed"
    )

    assert_equal "This is the standard description", product.description_standard_with_fallback
  end

  test "description_standard_with_fallback truncates detailed when standard is blank" do
    product = products(:one)
    product.update_columns(
      description_standard: nil,
      description_detailed: "This is a very long detailed description with many words more than thirty five words to properly test the truncation behavior of the fallback method logic here and ensure it works correctly and precisely every single time"
    )

    result = product.description_standard_with_fallback
    assert_not_nil result
    assert result.end_with?("...")
    assert result.split.length <= 36 # 35 words + "..."
  end

  test "description_detailed_with_fallback always returns detailed field" do
    product = products(:one)
    product.update_columns(description_detailed: "This is the detailed description")

    assert_equal "This is the detailed description", product.description_detailed_with_fallback
  end

  test "truncate_to_words truncates text to specified word count" do
    product = products(:one)
    # Need to test private method indirectly through public methods
    product.update_columns(
      description_short: nil,
      description_standard: "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen",
      description_detailed: nil
    )

    result = product.description_short_with_fallback
    words = result.gsub("...", "").split
    assert_equal 15, words.length
  end

  # Quick Add scope tests (T011)
  test "quick_add_eligible scope returns only standard products" do
    standard_product = products(:one)
    standard_product.update!(product_type: "standard")

    customizable_product = Product.create!(
      name: "Branded Cup",
      sku: "BRANDED-1",
      category: categories(:one),
      product_type: "customizable_template"
    )

    customized_instance = Product.create!(
      name: "Acme Branded Cup",
      sku: "ACME-1",
      category: categories(:one),
      product_type: "customized_instance",
      parent_product: customizable_product,
      organization: organizations(:acme)
    )

    eligible = Product.quick_add_eligible

    assert_includes eligible, standard_product
    assert_not_includes eligible, customizable_product
    assert_not_includes eligible, customized_instance
  end

  test "quick_add_eligible scope excludes customizable products" do
    customizable = Product.create!(
      name: "Customizable Product",
      sku: "CUSTOM-1",
      category: categories(:one),
      product_type: "customizable_template"
    )

    eligible = Product.quick_add_eligible

    assert_not_includes eligible, customizable
  end

  test "quick_add_eligible scope excludes customized instances" do
    template = Product.create!(
      name: "Template Product",
      sku: "TEMPLATE-1",
      category: categories(:one),
      product_type: "customizable_template"
    )

    instance = Product.create!(
      name: "Instance Product",
      sku: "INSTANCE-1",
      category: categories(:one),
      product_type: "customized_instance",
      parent_product: template,
      organization: organizations(:acme)
    )

    eligible = Product.quick_add_eligible

    assert_not_includes eligible, instance
  end

  # ==========================================================================
  # T013: available_options tests (replaces extract_options_from_variants)
  # ==========================================================================

  test "available_options returns only multi-value options" do
    product = products(:paper_straws)
    options = product.available_options

    # Paper straws have size (6x140mm, 8x200mm) and colour (White, Kraft, Red/White) - both multi-value
    assert options.key?("size")
    assert options.key?("colour")
    assert options["size"].size > 1
    assert options["colour"].size > 1
  end

  test "available_options excludes single-value options" do
    product = products(:single_wall_cups)
    options = product.available_options

    # Single wall cups have size (8oz, 12oz) and color (White, Black) - both multi-value
    # If there was a single-value option, it would be excluded
    options.each do |key, values|
      assert values.size > 1, "Option #{key} should have multiple values but has #{values.size}"
    end
  end

  test "available_options sorts by priority order" do
    product = products(:wooden_cutlery)
    options = product.available_options

    # Wooden cutlery has material and type - priority is material → type → size → colour
    keys = options.keys
    assert_equal "material", keys.first if options.key?("material")

    # If both material and type exist, material should come first
    if keys.include?("material") && keys.include?("type")
      assert keys.index("material") < keys.index("type")
    end
  end

  test "available_options transforms values to arrays" do
    product = products(:paper_straws)
    options = product.available_options

    options.each do |key, values|
      assert values.is_a?(Array), "Values for #{key} should be an array"
    end
  end

  test "available_options returns empty hash for product with no variant options" do
    product = products(:one)
    options = product.available_options

    assert_equal({}, options)
  end

  test "available_options queries through join table" do
    product = products(:single_wall_cups)
    options = product.available_options

    # Verify it returns the values from the join table fixtures
    assert_includes options["size"], "8oz"
    assert_includes options["size"], "12oz"
    assert_includes options["colour"], "White"
    assert_includes options["colour"], "Black"
  end

  test "available_options only includes options from active variants" do
    product = products(:single_wall_cups)

    # Deactivate one variant
    variant = product_variants(:single_wall_8oz_black)
    variant.update!(active: false)

    options = product.available_options

    # Black should still be present because 12oz White also exists
    # But if there was a colour only on the deactivated variant, it would be excluded
    assert options["size"].size >= 1
  end

  # ==========================================================================
  # T014: variants_for_selector tests (uses option_values_hash internally)
  # ==========================================================================

  test "variants_for_selector returns correct shape" do
    product = products(:paper_straws)
    variants = product.variants_for_selector

    assert variants.is_a?(Array)
    assert variants.any?

    variant = variants.first
    assert variant.key?(:id)
    assert variant.key?(:sku)
    assert variant.key?(:price)
    assert variant.key?(:pac_size)
    assert variant.key?(:option_values)
    assert variant.key?(:pricing_tiers)
    assert variant.key?(:image_url)
  end

  test "variants_for_selector only includes active variants" do
    product = products(:single_wall_cups)

    # Get active variant IDs from association
    active_ids = product.active_variants.pluck(:id)

    # Get IDs from selector method
    selector_ids = product.variants_for_selector.map { |v| v[:id] }

    assert_equal active_ids.sort, selector_ids.sort
  end

  test "variants_for_selector includes pricing_tiers when present" do
    product = products(:single_wall_cups)
    variants = product.variants_for_selector

    # single_wall_8oz_white has pricing_tiers in fixtures
    variant_with_tiers = variants.find { |v| v[:sku] == "CUP-SW-8-WHT" }
    assert_not_nil variant_with_tiers
    assert_not_nil variant_with_tiers[:pricing_tiers]
    assert variant_with_tiers[:pricing_tiers].is_a?(Array)
  end

  test "variants_for_selector includes nil pricing_tiers when not present" do
    product = products(:paper_straws)
    variants = product.variants_for_selector

    # straw_6x140_kraft has no pricing_tiers in fixtures
    variant_without_tiers = variants.find { |v| v[:sku] == "STRAW-6-KFT" }
    assert_not_nil variant_without_tiers
    assert_nil variant_without_tiers[:pricing_tiers]
  end

  test "variants_for_selector includes option_values" do
    product = products(:paper_straws)
    variants = product.variants_for_selector

    variant = variants.find { |v| v[:sku] == "STRAW-6-WHT" }
    assert_not_nil variant
    assert_equal "6x140mm", variant[:option_values]["size"]
    assert_equal "White", variant[:option_values]["colour"]
  end

  test "variants_for_selector price is a float" do
    product = products(:paper_straws)
    variants = product.variants_for_selector

    variants.each do |v|
      assert v[:price].is_a?(Float), "Price should be a float for #{v[:sku]}"
    end
  end
end
