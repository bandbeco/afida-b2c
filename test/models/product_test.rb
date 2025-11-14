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
    assert_not active_products.include?(products(:two)) # Product two is inactive
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
    assert_includes product.options, product_options(:color)
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
end
