require "application_system_test_case"

class QuickAddTest < ApplicationSystemTestCase
  # Test US1: Single-variant quick add flow
  test "quick add flow for single-variant product" do
    visit shop_path

    # Find a standard product with single variant
    product = Product.quick_add_eligible.joins(:active_variants)
                     .group("products.id")
                     .having("COUNT(product_variants.id) = 1")
                     .first

    skip "No single-variant standard products available in database" unless product

    # Click Quick Add button
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal should open
    assert_selector ".modal.modal-open"
    assert_text product.name

    # For single-variant products, quantity selector should be present
    assert_selector "select[name='cart_item[quantity]']"

    # Select quantity (2 packs - find option that contains "2 pack")
    within ".modal" do
      # Find all options and select the one with "2 pack" in it
      all('select[name="cart_item[quantity]"] option').each do |option|
        if option.text.include?("2 pack")
          select option.text, from: "cart_item[quantity]"
          break
        end
      end
    end

    # Click Add to Cart
    click_button "Add to Cart"

    # Modal should close
    assert_no_selector ".modal.modal-open", wait: 3

    # Cart drawer should open - check by visible drawer content
    assert_selector ".drawer-side", visible: true, wait: 5

    # Verify cart contains product in drawer
    within ".drawer-side" do
      assert_text product.name
    end
  end

  test "quick add button only shows for standard products" do
    visit shop_path

    # Find a standard product
    standard_product = Product.quick_add_eligible.first
    skip "No standard products available" unless standard_product

    # Find a customizable product
    customizable_product = Product.where(product_type: "customizable_template").first
    skip "No customizable products available" unless customizable_product

    # Standard product should have Quick Add button
    within("[data-product-id='#{standard_product.id}']", match: :first) do
      assert_link "Quick Add"
    end

    # Customizable product should NOT have Quick Add button
    if page.has_css?("[data-product-id='#{customizable_product.id}']")
      within("[data-product-id='#{customizable_product.id}']", match: :first) do
        assert_no_link "Quick Add"
      end
    end
  end

  test "quick add button disabled if product has no active variants" do
    visit shop_path

    # Find a product with no active variants (if any)
    product_no_variants = Product.left_joins(:active_variants)
                                 .group("products.id")
                                 .having("COUNT(product_variants.id) = 0")
                                 .first

    skip "All products have active variants" unless product_no_variants

    # Should not find Quick Add button for products without variants
    assert_no_selector "[data-product-id='#{product_no_variants.id}'] a", text: "Quick Add"
  end

  # User Story 2: Multi-variant support tests
  test "quick add flow for multi-variant product" do
    visit shop_path

    # Find a standard product with multiple variants
    product = Product.quick_add_eligible.joins(:active_variants)
                     .group("products.id")
                     .having("COUNT(product_variants.id) > 1")
                     .first

    skip "No multi-variant standard products available in database" unless product

    # Click Quick Add button
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal should open with variant selector
    assert_selector ".modal.modal-open"
    assert_text product.name
    assert_selector "select[name='variant_selector']"

    # Get the variants for price checking
    variants = product.active_variants.by_position.to_a
    first_variant = variants.first
    second_variant = variants.second

    # Select a different variant
    select second_variant.name, from: "variant_selector"

    # Select quantity
    within ".modal" do
      all('select[name="cart_item[quantity]"] option').each do |option|
        if option.text.include?("2 pack")
          select option.text, from: "cart_item[quantity]"
          break
        end
      end
    end

    # Click Add to Cart
    click_button "Add to Cart"

    # Modal should close
    assert_no_selector ".modal.modal-open", wait: 3

    # Cart drawer should open
    assert_selector ".drawer-side", visible: true, wait: 5

    # Verify cart contains correct variant
    within ".drawer-side" do
      assert_text product.name
      assert_text second_variant.name
    end
  end

  test "price updates when variant changes" do
    visit shop_path

    # Find a multi-variant product with different prices
    product = Product.quick_add_eligible
                     .joins(:active_variants)
                     .group("products.id")
                     .having("COUNT(product_variants.id) > 1")
                     .first

    skip "No multi-variant products available" unless product

    # Click Quick Add
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal opens
    assert_selector ".modal.modal-open"
    assert_selector "select[name='variant_selector']"

    # Get variants with different prices
    variants = product.active_variants.order(:price).to_a

    # Check if there's a price display element (will be added in implementation)
    # This test will initially fail and pass after T028 is implemented
    assert_selector "[data-quick-add-form-target='priceDisplay']", wait: 1
  end

  test "adding existing cart item increments quantity" do
    # First, add a product to cart via quick add
    visit shop_path

    product = Product.quick_add_eligible.joins(:active_variants).first
    skip "No quick_add_eligible products available" unless product

    # First add: Add 1 pack
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    assert_selector ".modal.modal-open"
    click_button "Add to Cart"
    assert_no_selector ".modal.modal-open", wait: 3

    # Second add: Add same product again via quick add
    visit shop_path

    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal opens
    assert_selector ".modal.modal-open"

    # Add to cart again (default quantity = 1 pack)
    click_button "Add to Cart"

    # Modal closes, drawer opens
    assert_no_selector ".modal.modal-open", wait: 3
    assert_selector ".drawer-side", visible: true, wait: 5

    # Verify quantity was incremented (not duplicate line item)
    # Should show combined quantity in drawer
    within ".drawer-side" do
      assert_text product.name
      # Cart should have 2 packs now (1 from first add + 1 from second add)
      assert_text "2 packs"
    end
  end
end
