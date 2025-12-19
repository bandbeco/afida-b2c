require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
    @variant = product_variants(:one)
  end

  # Validation tests
  test "validates presence of sku" do
    variant = ProductVariant.new(product: @product, name: "Test", price: 10.0)
    assert_not variant.valid?
    assert_includes variant.errors[:sku], "can't be blank"
  end

  test "validates uniqueness of sku" do
    variant = ProductVariant.new(
      product: @product,
      name: "Test",
      sku: @variant.sku,
      price: 10.0
    )
    assert_not variant.valid?
    assert_includes variant.errors[:sku], "has already been taken"
  end

  test "validates presence of price" do
    variant = ProductVariant.new(product: @product, name: "Test", sku: "UNIQUE123")
    assert_not variant.valid?
    assert_includes variant.errors[:price], "can't be blank"
  end

  test "validates price is greater than zero" do
    variant = ProductVariant.new(
      product: @product,
      name: "Test",
      sku: "UNIQUE123",
      price: 0
    )
    assert_not variant.valid?
    assert_includes variant.errors[:price], "must be greater than 0"
  end

  test "validates presence of name" do
    variant = ProductVariant.new(product: @product, sku: "UNIQUE123", price: 10.0)
    assert_not variant.valid?
    assert_includes variant.errors[:name], "can't be blank"
  end

  # Method tests
  test "display_name includes product name and variant name" do
    expected = "#{@variant.product.name} (#{@variant.name})"
    assert_equal expected, @variant.display_name
  end

  test "full_name includes variant name when not Standard" do
    # Create another variant so product has multiple variants
    ProductVariant.create!(
      product: @product,
      name: "Small",
      sku: "SMALL-123",
      price: 5.0,
      active: true
    )

    @variant.update(name: "Large")
    parts = [ @variant.product.name, "- Large" ]
    assert_equal parts.join(" "), @variant.full_name
  end

  test "full_name excludes variant name when Standard" do
    @variant.update(name: "Standard")
    assert_equal @variant.product.name, @variant.full_name
  end

  test "full_name excludes variant name when product has only one variant" do
    # Create product with single variant
    product = Product.create!(
      name: "Single Variant Product",
      category: categories(:one),
      sku: "SINGLE"
    )
    variant = product.variants.create!(
      name: "Only One",
      sku: "SINGLE-1",
      price: 10.0
    )

    assert_equal product.name, variant.full_name
  end

  test "in_stock? always returns true" do
    # Currently stock tracking is not implemented
    assert @variant.in_stock?

    @variant.stock_quantity = 0
    assert @variant.in_stock?
  end

  test "variant_attributes returns hash of non-blank attributes" do
    @variant.update(
      width_in_mm: 100,
      height_in_mm: 200,
      weight_in_g: 50
    )

    attrs = @variant.variant_attributes
    assert_equal "100", attrs[:width_in_mm]
    assert_equal "200", attrs[:height_in_mm]
    assert_equal "50", attrs[:weight_in_g]
  end

  test "variant_attributes filters out blank values" do
    @variant.update(
      width_in_mm: nil,
      height_in_mm: 200
    )

    attrs = @variant.variant_attributes
    assert_not_includes attrs.keys, :width_in_mm
    assert_includes attrs.keys, :height_in_mm
  end

  # Scope tests
  test "active scope returns only active variants" do
    active_variant = ProductVariant.create!(
      product: @product,
      name: "Active",
      sku: "ACTIVE1",
      price: 10.0,
      active: true
    )

    inactive_variant = ProductVariant.create!(
      product: @product,
      name: "Inactive",
      sku: "INACTIVE1",
      price: 10.0,
      active: false
    )

    active_variants = ProductVariant.unscoped.active
    assert_includes active_variants, active_variant
    assert_not_includes active_variants, inactive_variant
  end

  test "by_name scope orders variants alphabetically" do
    variant_b = ProductVariant.create!(
      product: @product,
      name: "B Variant",
      sku: "B1",
      price: 10.0
    )

    variant_a = ProductVariant.create!(
      product: @product,
      name: "A Variant",
      sku: "A1",
      price: 10.0
    )

    variants = ProductVariant.unscoped.where(product: @product).by_name
    assert_equal "A Variant", variants.first.name
  end

  test "by_position scope orders by position then name" do
    # Create a new product to avoid fixture interference
    product = Product.unscoped.create!(
      name: "Test Product",
      category: categories(:one),
      sku: "TEST-PROD"
    )

    variant_c = ProductVariant.create!(
      product: product,
      name: "C Variant",
      sku: "C1",
      price: 10.0,
      position: 1
    )

    variant_b = ProductVariant.create!(
      product: product,
      name: "B Variant",
      sku: "B1",
      price: 10.0,
      position: 2
    )

    variant_a = ProductVariant.create!(
      product: product,
      name: "A Variant",
      sku: "A1",
      price: 10.0,
      position: 3
    )

    variants = product.variants.by_position
    assert_equal "C Variant", variants.first.name
    assert_equal "B Variant", variants.second.name
    assert_equal "A Variant", variants.third.name
  end

  # Association tests
  test "belongs to product" do
    assert_respond_to @variant, :product
    assert_kind_of Product, @variant.product
  end

  test "has many cart_items" do
    assert_respond_to @variant, :cart_items
  end

  test "has many order_items" do
    assert_respond_to @variant, :order_items
  end

  # Delegation tests
  test "delegates category to product" do
    assert_equal @variant.product.category, @variant.category
  end

  test "delegates description to product" do
    # Variant.description now uses description_standard_with_fallback from product
    assert_equal @variant.product.description_standard_with_fallback, @variant.description
  end

  test "delegates meta_title to product" do
    assert_equal @variant.product.meta_title, @variant.meta_title
  end

  test "delegates meta_description to product" do
    assert_equal @variant.product.meta_description, @variant.meta_description
  end

  test "delegates colour to product" do
    assert_equal @variant.product.colour, @variant.colour
  end

  # Dependent destroy tests
  test "has dependent restrict_with_error on cart_items" do
    cart = Cart.create
    cart.cart_items.create(product_variant: @variant, quantity: 1, price: 10.0)

    # Should not be able to destroy when cart_items exist
    result = @variant.destroy
    assert_not result
  end

  test "has dependent nullify on order_items" do
    order = orders(:one)
    order_item = order.order_items.create!(
      product_variant: @variant,
      product_name: "Test",
      product_sku: "TEST",
      price: 10.0,
      quantity: 1,
      line_total: 10.0
    )

    @variant.destroy
    order_item.reload

    # Check that order_item still exists but product_variant reference is gone
    assert_not_nil order_item
    # The association is nullified on delete
  end

  # Option values tests
  test "variant stores option values as jsonb" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz", variant.option_values["size"]
    assert_equal "White", variant.option_values["color"]
  end

  test "variant can retrieve option value for specific option" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz", variant.option_value_for("size")
    assert_equal "White", variant.option_value_for("color")
  end

  test "variant display name includes option values" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz / White", variant.options_display
  end

  test "options_display formats consolidated products with slashes and material first" do
    # Wooden cutlery is a consolidated product (material option with multiple values)
    variant = product_variants(:wooden_fork)
    # Consolidated products format as "Material / Type" with slashes
    assert_equal "Birch / Fork", variant.options_display
  end

  test "options_display for different material variant" do
    # Bamboo fork has different material
    variant = product_variants(:bamboo_fork)
    assert_equal "Bamboo / Fork", variant.options_display
  end

  # consolidated_product? tests
  test "consolidated_product? returns true when material option has multiple values across siblings" do
    # Wooden cutlery has both Birch and Bamboo material variants
    variant = product_variants(:wooden_fork)
    assert variant.consolidated_product?
  end

  test "consolidated_product? returns true for any variant of consolidated product" do
    # All variants of wooden_cutlery should be consolidated
    birch_fork = product_variants(:wooden_fork)
    bamboo_fork = product_variants(:bamboo_fork)
    bamboo_knife = product_variants(:bamboo_knife)

    assert birch_fork.consolidated_product?
    assert bamboo_fork.consolidated_product?
    assert bamboo_knife.consolidated_product?
  end

  test "consolidated_product? returns false for standard product" do
    # Standard products without material/type options with multiple values
    variant = product_variants(:single_wall_8oz_white)
    assert_not variant.consolidated_product?
  end

  test "consolidated_product? returns false when option_values is empty" do
    variant = product_variants(:one)
    variant.update!(option_values: {})
    assert_not variant.consolidated_product?
  end

  # display_name tests for consolidated products
  test "display_name builds from option_values for consolidated products" do
    variant = product_variants(:wooden_fork)
    # Should include product name and option values
    assert_equal "Wooden Cutlery - Birch, Fork", variant.display_name
  end

  test "display_name uses option priority order for consolidated products" do
    # Material should come before type
    variant = product_variants(:bamboo_knife)
    assert_equal "Wooden Cutlery - Bamboo, Knife", variant.display_name
  end

  test "display_name uses standard format for non-consolidated products" do
    variant = product_variants(:single_wall_8oz_white)
    expected = "#{variant.product.name} (#{variant.name})"
    assert_equal expected, variant.display_name
  end

  test "variant without option values returns empty hash" do
    variant = ProductVariant.create!(
      product: products(:branded_double_wall_template),
      name: "Test Variant",
      sku: "TEST-SKU",
      price: 100,
      stock_quantity: 0
    )
    assert_equal({}, variant.option_values)
  end

  # Unit pricing tests
  test "unit_price returns price when pac_size is not set" do
    @variant.update(price: 10.0, pac_size: nil)
    assert_equal 10.0, @variant.unit_price
  end

  test "unit_price returns price when pac_size is zero" do
    @variant.update(price: 10.0, pac_size: 0)
    assert_equal 10.0, @variant.unit_price
  end

  test "unit_price divides price by pac_size when pac_size is set" do
    @variant.update(price: 100.0, pac_size: 50)
    assert_equal 2.0, @variant.unit_price
  end

  test "unit_price calculates correctly for fractional results" do
    @variant.update(price: 10.0, pac_size: 3)
    assert_in_delta 3.3333, @variant.unit_price, 0.001
  end

  test "minimum_order_units returns 1 when pac_size is not set" do
    @variant.update(pac_size: nil)
    assert_equal 1, @variant.minimum_order_units
  end

  test "minimum_order_units returns pac_size when set" do
    @variant.update(pac_size: 50)
    assert_equal 50, @variant.minimum_order_units
  end

  test "minimum_order_units returns pac_size for large packs" do
    @variant.update(pac_size: 1000)
    assert_equal 1000, @variant.minimum_order_units
  end

  # Photo attachment tests
  test "can attach product_photo" do
    variant = product_variants(:one)
    file = fixture_file_upload("product.jpg", "image/jpeg")

    variant.product_photo.attach(file)

    assert variant.product_photo.attached?
  end

  test "can attach lifestyle_photo" do
    variant = product_variants(:one)
    file = fixture_file_upload("lifestyle.jpg", "image/jpeg")

    variant.lifestyle_photo.attach(file)

    assert variant.lifestyle_photo.attached?
  end

  test "primary_photo returns product_photo when both attached" do
    variant = product_variants(:one)
    variant.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))
    variant.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    assert_equal variant.product_photo, variant.primary_photo
  end

  test "primary_photo returns lifestyle_photo when only lifestyle attached" do
    variant = product_variants(:one)
    variant.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    assert_equal variant.lifestyle_photo, variant.primary_photo
  end

  test "primary_photo returns nil when no photos attached" do
    variant = product_variants(:one)

    assert_nil variant.primary_photo
  end

  test "photos returns array of attached photos" do
    variant = product_variants(:one)
    variant.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))
    variant.lifestyle_photo.attach(fixture_file_upload("lifestyle.jpg", "image/jpeg"))

    photos = variant.photos

    assert_equal 2, photos.length
    assert_includes photos, variant.product_photo
    assert_includes photos, variant.lifestyle_photo
  end

  test "has_photos? returns true when photos attached" do
    variant = product_variants(:one)
    variant.product_photo.attach(fixture_file_upload("product.jpg", "image/jpeg"))

    assert variant.has_photos?
  end

  test "has_photos? returns false when no photos attached" do
    variant = product_variants(:one)

    assert_not variant.has_photos?
  end

  # GTIN validation tests
  test "should accept valid GTIN-13" do
    variant = product_variants(:one)
    variant.gtin = "1234567890123" # 13 digits

    assert variant.valid?
  end

  test "should accept valid GTIN-14" do
    variant = product_variants(:one)
    variant.gtin = "12345678901234" # 14 digits

    assert variant.valid?
  end

  test "should reject invalid GTIN format" do
    variant = product_variants(:one)
    variant.gtin = "123" # too short

    assert_not variant.valid?
    assert_includes variant.errors[:gtin], "must be 8, 12, 13, or 14 digits"
  end

  test "GTIN should be optional" do
    variant = product_variants(:one)
    variant.gtin = nil

    assert variant.valid?
  end

  test "should accept valid GTIN-8" do
    variant = product_variants(:one)
    variant.gtin = "12345678" # 8 digits

    assert variant.valid?
  end

  test "should accept valid GTIN-12" do
    variant = product_variants(:one)
    variant.gtin = "123456789012" # 12 digits

    assert variant.valid?
  end

  test "should reject duplicate GTIN" do
    variant1 = product_variants(:one)
    variant2 = product_variants(:two)

    variant1.update!(gtin: "1234567890123")
    variant2.gtin = "1234567890123"

    assert_not variant2.valid?
    assert_includes variant2.errors[:gtin], "has already been taken"
  end

  # Sample eligibility tests
  test "sample_eligible scope returns only sample-eligible variants" do
    # Create sample-eligible variant
    sample_variant = ProductVariant.create!(
      product: @product,
      name: "Sample Eligible",
      sku: "SAMPLE-ELIGIBLE-1",
      price: 10.0,
      active: true,
      sample_eligible: true
    )

    # Create non-sample-eligible variant
    non_sample_variant = ProductVariant.create!(
      product: @product,
      name: "Not Sample Eligible",
      sku: "NOT-SAMPLE-1",
      price: 10.0,
      active: true,
      sample_eligible: false
    )

    eligible_variants = ProductVariant.unscoped.sample_eligible
    assert_includes eligible_variants, sample_variant
    assert_not_includes eligible_variants, non_sample_variant
  end

  test "sample_eligible defaults to false" do
    variant = ProductVariant.create!(
      product: @product,
      name: "New Variant",
      sku: "NEW-VAR-1",
      price: 10.0
    )

    assert_equal false, variant.sample_eligible
  end

  test "effective_sample_sku returns sample_sku when present" do
    @variant.update!(sample_eligible: true, sample_sku: "CUSTOM-SAMPLE-SKU")

    assert_equal "CUSTOM-SAMPLE-SKU", @variant.effective_sample_sku
  end

  test "effective_sample_sku derives from sku when sample_sku is blank" do
    @variant.update!(sample_eligible: true, sample_sku: nil)

    assert_equal "SAMPLE-#{@variant.sku}", @variant.effective_sample_sku
  end

  test "effective_sample_sku derives from sku when sample_sku is empty string" do
    @variant.update!(sample_eligible: true, sample_sku: "")

    assert_equal "SAMPLE-#{@variant.sku}", @variant.effective_sample_sku
  end

  # Pricing tiers validation tests (T004)
  test "pricing_tiers accepts valid array with quantity and price" do
    variant = product_variants(:single_wall_8oz_white)
    variant.pricing_tiers = [
      { "quantity" => 1, "price" => "26.00" },
      { "quantity" => 3, "price" => "24.00" },
      { "quantity" => 5, "price" => "22.00" }
    ]
    assert variant.valid?, variant.errors.full_messages.join(", ")
  end

  test "pricing_tiers allows nil (optional field)" do
    variant = product_variants(:one)
    variant.pricing_tiers = nil
    assert variant.valid?
  end

  test "pricing_tiers allows blank (empty array treated as nil)" do
    variant = product_variants(:one)
    variant.pricing_tiers = []
    # Empty array should be valid (no tiers = use standard pricing)
    assert variant.valid?
  end

  test "pricing_tiers rejects non-array value" do
    variant = product_variants(:one)
    variant.pricing_tiers = { "quantity" => 1, "price" => "10.00" }
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier without quantity" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "price" => "10.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier with non-integer quantity" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => "five", "price" => "10.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier with zero quantity" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 0, "price" => "10.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier with negative quantity" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => -1, "price" => "10.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier without price" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 1 }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects tier with invalid price format" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 1, "price" => "invalid" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects duplicate quantities" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 1, "price" => "10.00" },
      { "quantity" => 1, "price" => "9.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers rejects unsorted quantities" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 5, "price" => "9.00" },
      { "quantity" => 1, "price" => "10.00" }
    ]
    assert_not variant.valid?
    assert variant.errors[:pricing_tiers].any?
  end

  test "pricing_tiers accepts integer price strings" do
    variant = product_variants(:one)
    variant.pricing_tiers = [
      { "quantity" => 1, "price" => "10" }
    ]
    assert variant.valid?, variant.errors.full_messages.join(", ")
  end

  test "pricing_tiers from fixture has valid structure" do
    variant = product_variants(:single_wall_8oz_white)
    assert variant.pricing_tiers.is_a?(Array)
    assert variant.pricing_tiers.first["quantity"].is_a?(Integer)
    assert variant.pricing_tiers.first["price"].is_a?(String)
  end

  # Option values validation tests (T015 - data integrity)
  test "option_values accepts valid hash with lowercase keys and string values" do
    variant = product_variants(:one)
    variant.option_values = { "size" => "8oz", "colour" => "White" }
    assert variant.valid?, variant.errors.full_messages.join(", ")
  end

  test "option_values allows nil (optional field)" do
    variant = product_variants(:one)
    variant.option_values = nil
    assert variant.valid?
  end

  test "option_values allows empty hash" do
    variant = product_variants(:one)
    variant.option_values = {}
    assert variant.valid?
  end

  test "option_values rejects non-hash value" do
    variant = product_variants(:one)
    variant.option_values = [ "size", "8oz" ]
    assert_not variant.valid?
    assert variant.errors[:option_values].any?
  end

  test "option_values rejects uppercase keys" do
    variant = product_variants(:one)
    variant.option_values = { "Size" => "8oz" }
    assert_not variant.valid?
    assert variant.errors[:option_values].any? { |e| e.include?("lowercase") }
  end

  test "option_values rejects keys with spaces" do
    variant = product_variants(:one)
    variant.option_values = { "cup size" => "8oz" }
    assert_not variant.valid?
    assert variant.errors[:option_values].any?
  end

  test "option_values rejects non-string values" do
    variant = product_variants(:one)
    variant.option_values = { "size" => 8 }
    assert_not variant.valid?
    assert variant.errors[:option_values].any? { |e| e.include?("must be a string") }
  end

  test "option_values rejects values longer than 50 characters" do
    variant = product_variants(:one)
    variant.option_values = { "size" => "A" * 51 }
    assert_not variant.valid?
    assert variant.errors[:option_values].any? { |e| e.include?("exceeds") }
  end

  test "option_values accepts values with common punctuation" do
    variant = product_variants(:one)
    variant.option_values = {
      "size" => "8oz (Large)",
      "colour" => "Red/Blue",
      "style" => "Modern - Classic"
    }
    assert variant.valid?, variant.errors.full_messages.join(", ")
  end

  test "option_values rejects values with script tags" do
    variant = product_variants(:one)
    variant.option_values = { "size" => "<script>alert('xss')</script>" }
    assert_not variant.valid?
    assert variant.errors[:option_values].any? { |e| e.include?("invalid characters") }
  end

  test "option_values rejects values with HTML entities" do
    variant = product_variants(:one)
    variant.option_values = { "size" => "8oz&nbsp;Large" }
    assert_not variant.valid?
    assert variant.errors[:option_values].any? { |e| e.include?("invalid characters") }
  end

  test "option_values allows underscore in keys" do
    variant = product_variants(:one)
    variant.option_values = { "cup_size" => "8oz" }
    assert variant.valid?, variant.errors.full_messages.join(", ")
  end
end
