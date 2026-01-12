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

  test "active scope should return only active products" do
    active_products = Product.active
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
  test "should generate slug from name on create if slug is blank" do
    product = Product.new(name: "New Awesome Product", sku: "NAP123", price: 10.00, category: @category)
    assert product.save
    assert_equal "new-awesome-product", product.slug
  end

  test "should use provided slug on create if slug is present" do
    product = Product.new(name: "New Awesome Product with Slug", sku: "NAPWS456", price: 10.00, category: @category, slug: "my-custom-slug")
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
    product = Product.create!(name: "Initial Name", sku: "REGENSKU1", price: 10.00, category: @category)
    # product.slug is now "initial-name" (generated from name, not sku + name)

    product.name = "Product For Slug Regeneration"
    product.sku = "REGENSKU2" # SKU might also change
    product.slug = "" # Manually clear the slug
    assert product.save
    assert_equal "product-for-slug-regeneration", product.slug
  end

  test "should regenerate slug on update if slug is manually set to nil" do
    product = Product.create!(name: "Initial Nil Name", sku: "NILSKU1", price: 10.00, category: @category)
    # product.slug is now "initial-nil-name"

    product.name = "Product For Nil Slug Regeneration"
    product.sku = "NILSKU2"
    product.slug = nil # Manually clear the slug by setting to nil
    assert product.save
    assert_equal "product-for-nil-slug-regeneration", product.slug
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

  # configuration_data column was removed during model restructure
  # Customized instances now use parent_product relationship instead

  test "standard and template products dont require parent or organization" do
    product = Product.new(
      name: "Test",
      sku: "TEST-STD-001",
      price: 10.00,
      product_type: "standard",
      category: categories(:one)
    )
    assert product.valid?
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

  # Custom label fields tests
  test "should have best_seller and b2b_priority fields" do
    product = products(:one)

    product.best_seller = true
    product.b2b_priority = "high"

    assert product.save
    assert product.best_seller
    assert_equal "high", product.b2b_priority
  end

  test "should validate b2b_priority values" do
    product = products(:one)
    product.b2b_priority = "invalid"

    assert_not product.valid?
    assert_includes product.errors[:b2b_priority], "is not included in the list"
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

    product2 = Product.create!(name: "Product 2", sku: "SKU2", price: 10.00, category: category2)

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

  test "sorted by price_asc orders products by price ascending" do
    # Create two products with different prices
    cheap = Product.create!(name: "Cheap Product", sku: "CHEAP", price: 1.00, category: categories(:one))
    expensive = Product.create!(name: "Expensive Product", sku: "EXPENSIVE", price: 10.00, category: categories(:one))

    results = Product.sorted("price_asc").to_a

    assert results.index(cheap) < results.index(expensive), "Cheap product should come before expensive"
  end

  test "sorted by price_desc orders products by price descending" do
    # Create products with different prices
    low_price = Product.create!(name: "Low Price Product", sku: "LOW", price: 5.00, category: categories(:one))
    mid_price = Product.create!(name: "Mid Price Product", sku: "MID", price: 50.00, category: categories(:one))
    high_price = Product.create!(name: "High Price Product", sku: "HIGH", price: 150.00, category: categories(:one))

    results = Product.sorted("price_desc").to_a

    # Should sort by price descending: high_price (150) > mid_price (50) > low_price (5)
    assert results.index(high_price) < results.index(mid_price), "High price product should come before mid price"
    assert results.index(mid_price) < results.index(low_price), "Mid price product should come before low price"
  end

  test "sorted returns all products when sort param is nil" do
    product1 = Product.create!(name: "Product A", sku: "PROD-A", price: 10.00, category: categories(:one))
    product2 = Product.create!(name: "Product B", sku: "PROD-B", price: 20.00, category: categories(:one))

    results = Product.sorted(nil).to_a

    # Should return all products without specific ordering
    assert_includes results, product1
    assert_includes results, product2
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
      price: 0.01,
      category: categories(:one),
      product_type: "customizable_template"
    )

    customized_instance = Product.create!(
      name: "Acme Branded Cup",
      sku: "ACME-1",
      price: 100.00,
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
      price: 0.01,
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
      price: 0.01,
      category: categories(:one),
      product_type: "customizable_template"
    )

    instance = Product.create!(
      name: "Instance Product",
      sku: "INSTANCE-1",
      price: 100.00,
      category: categories(:one),
      product_type: "customized_instance",
      parent_product: template,
      organization: organizations(:acme)
    )

    eligible = Product.quick_add_eligible

    assert_not_includes eligible, instance
  end
end
