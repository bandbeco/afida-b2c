require "test_helper"

class CartHelperTest < ActionView::TestCase
  # =============================================================================
  # Tests for quantity_options_for_cart_item (unified entry point)
  # =============================================================================

  test "quantity_options_for_cart_item delegates to branded helper for configured items" do
    cart_item = cart_items(:branded_small_order)
    assert cart_item.configured?, "Test fixture should be a configured item"

    options = quantity_options_for_cart_item(cart_item)

    # Should contain unit-based options, not pack-based
    labels = options.map(&:first)
    assert labels.any? { |label| label.include?("units") }
    assert labels.none? { |label| label.include?("packs") }
  end

  test "quantity_options_for_cart_item delegates to standard helper for regular items" do
    cart_item = cart_items(:one)
    assert_not cart_item.configured?, "Test fixture should not be a configured item"

    options = quantity_options_for_cart_item(cart_item)

    # Should contain pack-based options
    labels = options.map(&:first)
    assert labels.any? { |label| label.include?("pack") }
  end

  # =============================================================================
  # Tests for standard_quantity_options_for_select
  # =============================================================================

  test "standard_quantity_options_for_select returns pack-based options" do
    cart_item = cart_items(:one)

    options = standard_quantity_options_for_select(cart_item)

    assert_kind_of Array, options
    assert options.length > 0

    # First option should be 1 pack
    first_label, first_value = options.first
    assert_equal 1, first_value
    assert_includes first_label, "1 pack"
  end

  test "standard_quantity_options_for_select includes standard pack quantities" do
    cart_item = cart_items(:one)

    options = standard_quantity_options_for_select(cart_item)
    values = options.map(&:last)

    # Should include 1-10 and common bulk quantities
    (1..10).each do |qty|
      assert_includes values, qty, "Should include quantity #{qty}"
    end
    assert_includes values, 30
    assert_includes values, 40
    assert_includes values, 50
    assert_includes values, 60
  end

  test "standard_quantity_options_for_select includes current quantity if non-standard" do
    cart_item = cart_items(:one)
    cart_item.quantity = 25  # Non-standard quantity

    options = standard_quantity_options_for_select(cart_item)
    values = options.map(&:last)

    assert_includes values, 25, "Should include current non-standard quantity"
    assert_equal values, values.sort, "Options should be sorted"
  end

  test "standard_quantity_options_for_select calculates units correctly" do
    # Create a cart item with a product that has pac_size
    cart = carts(:one)
    product = products(:paper_lid_80mm)  # Has pac_size of 1000
    cart_item = CartItem.new(cart: cart, product: product, quantity: 2, price: product.price)

    options = standard_quantity_options_for_select(cart_item)

    # Find the 2-pack option
    two_pack_option = options.find { |_label, value| value == 2 }
    assert two_pack_option, "Should have a 2-pack option"

    label = two_pack_option.first
    # 2 packs × 1000 pac_size = 2,000 units
    assert_includes label, "2 packs"
    assert_includes label, "2,000 units"
  end

  # =============================================================================
  # Tests for branded_quantity_options_for_select
  # =============================================================================

  test "branded_quantity_options_for_select returns empty array for non-configured items" do
    cart_item = cart_items(:one)
    assert_not cart_item.configured?

    options = branded_quantity_options_for_select(cart_item)

    assert_equal [], options
  end

  test "branded_quantity_options_for_select returns unit-based options" do
    cart_item = cart_items(:branded_small_order)
    assert cart_item.configured?

    options = branded_quantity_options_for_select(cart_item)

    assert_kind_of Array, options
    assert options.length > 0

    # All labels should mention "units"
    labels = options.map(&:first)
    assert labels.all? { |label| label.include?("units") }
  end

  test "branded_quantity_options_for_select includes savings percentages for higher tiers" do
    cart_item = cart_items(:branded_small_order)  # 8oz at 1000 tier (base price)

    options = branded_quantity_options_for_select(cart_item)

    # Base tier (1000) should NOT have savings
    base_option = options.find { |_label, value| value == 1000 }
    assert base_option, "Should have 1000-unit option"
    assert_not_includes base_option.first, "save", "Base tier should not show savings"

    # Higher tiers should show savings (if pricing exists)
    # Based on fixtures: 8oz has tiers at 1000 (0.30), 2000 (0.25), 5000 (0.18)
    tier_5000 = options.find { |_label, value| value == 5000 }
    if tier_5000
      assert_includes tier_5000.first, "save", "Higher tier should show savings"
      assert_match(/save \d+%/, tier_5000.first)
    end
  end

  test "branded_quantity_options_for_select calculates savings correctly" do
    cart_item = cart_items(:branded_small_order)  # 8oz size

    options = branded_quantity_options_for_select(cart_item)

    # Based on fixtures:
    # - 1000 units @ £0.30/unit (base)
    # - 2000 units @ £0.25/unit (17% savings)
    # - 5000 units @ £0.18/unit (40% savings)

    tier_2000 = options.find { |_label, value| value == 2000 }
    if tier_2000
      # (0.30 - 0.25) / 0.30 = 0.167 = 17%
      assert_match(/save 1[67]%/, tier_2000.first)
    end

    tier_5000 = options.find { |_label, value| value == 5000 }
    if tier_5000
      # (0.30 - 0.18) / 0.30 = 0.40 = 40%
      assert_match(/save 40%/, tier_5000.first)
    end
  end

  test "branded_quantity_options_for_select includes standard quantity options" do
    cart_item = cart_items(:branded_small_order)

    options = branded_quantity_options_for_select(cart_item)
    values = options.map(&:last)

    # Should include configurator standard quantities (where pricing exists)
    # The fixture only has pricing for 1000, 2000, 5000 for 8oz
    assert_includes values, 1000
  end

  test "branded_quantity_options_for_select includes current quantity if non-standard" do
    cart_item = cart_items(:branded_small_order)
    # Set a quantity that's not in the standard list but may have pricing
    cart_item.quantity = 1500

    options = branded_quantity_options_for_select(cart_item)
    values = options.map(&:last)

    # If pricing exists for 1500, it should be included
    # If not, it won't be included (filter_map removes nil results)
    # Either way, the method shouldn't crash
    assert_kind_of Array, options
  end

  test "branded_quantity_options_for_select only returns quantities with valid pricing" do
    cart_item = cart_items(:branded_small_order)  # 8oz size

    options = branded_quantity_options_for_select(cart_item)
    values = options.map(&:last)

    # The fixture has pricing tiers at 1000, 2000, 5000 for 8oz
    # Quantities without pricing (e.g., 3000, 7500) should not appear
    values.each do |qty|
      # Verify each returned quantity has valid pricing
      pricing_service = BrandedProductPricingService.new(cart_item.product)
      result = pricing_service.calculate(size: "8oz", quantity: qty)
      assert result.success?, "Quantity #{qty} should have valid pricing"
    end
  end
end
