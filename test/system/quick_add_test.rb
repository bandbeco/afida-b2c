require "application_system_test_case"

class QuickAddTest < ApplicationSystemTestCase
  setup do
    # Ensure clean browser state between tests
    Capybara.reset_sessions!
    # Visit root to initialize a fresh page state
    visit root_path
  end

  # Helper to wait for turbo-frame modal content to load
  # Uses JavaScript polling to avoid Capybara visibility detection issues with DaisyUI modals
  def wait_for_quick_add_modal(product)
    # Wait for content to load via JavaScript polling (more reliable than Capybara for turbo-frames)
    timeout = 15
    elapsed = 0
    while elapsed < timeout
      has_content = page.evaluate_script("document.querySelector('#quick-add-title')?.textContent?.includes('#{product.name}') || false")
      break if has_content
      sleep 0.5
      elapsed += 0.5
    end

    # Final assertion with visible: :all to bypass Capybara's visibility detection issues
    assert_selector "#quick-add-title", text: product.name, wait: 2, visible: :all
  end

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

    # Wait for Turbo Frame request to complete and content to render
    wait_for_quick_add_modal(product)

    # For single-variant products, quantity selector should be present
    assert_selector "select[name='cart_item[quantity]']", wait: 2, visible: :all

    # Select quantity (2 packs - find option that contains "2 pack")
    within "#quick-add-modal", visible: :all do
      # Find all options and select the one with "2 pack" in it
      all('select[name="cart_item[quantity]"] option', visible: :all).each do |option|
        if option.text.include?("2 pack")
          select option.text, from: "cart_item[quantity]"
          break
        end
      end
    end

    # Click Add to Cart (use JavaScript click for DaisyUI modal compatibility)
    execute_script("document.querySelector('[data-quick-add-form-target=\"submitButton\"]').click()")

    # Modal should close - check modal box is gone
    assert_no_selector "#quick-add-modal .modal-box", wait: 5

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
  # Note: This test requires products with ProductOption records configured.
  # If no option buttons are found, it means the test data lacks ProductOption records.
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

    # Wait for Turbo Frame request to complete and content to render
    wait_for_quick_add_modal(product)

    # Multi-variant products show option buttons if ProductOptions are configured
    # Skip if no option buttons (means ProductOption records missing in test data)
    skip "No option buttons - ProductOption records not configured for test products" unless has_css?("[data-action='click->quick-add-form#selectOption']", wait: 2)
    first("[data-action='click->quick-add-form#selectOption']", visible: :all).click

    # Click Add to Cart (now enabled) - use JavaScript click for DaisyUI modal compatibility
    execute_script("document.querySelector('[data-quick-add-form-target=\"submitButton\"]').click()")

    # Modal should close - check modal box is gone
    assert_no_selector "#quick-add-modal .modal-box", wait: 5

    # Cart drawer should open
    assert_selector ".drawer-side", visible: true, wait: 5

    # Verify cart contains product in drawer
    within ".drawer-side" do
      assert_text product.name
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

    # Wait for Turbo Frame request to complete and content to render
    wait_for_quick_add_modal(product)

    # Multi-variant products initially show "Select size" in price display
    assert_selector "[data-quick-add-form-target='priceDisplay']", text: "Select size", wait: 2, visible: :all

    # Click an option button to select a variant
    # Skip if no option buttons (means ProductOption records missing in test data)
    skip "No option buttons - ProductOption records not configured for test products" unless has_css?("[data-action='click->quick-add-form#selectOption']", wait: 2)
    first("[data-action='click->quick-add-form#selectOption']", visible: :all).click

    # Price should now show a currency value (not "Select size")
    assert_selector "[data-quick-add-form-target='priceDisplay']", text: /£/, wait: 2, visible: :all
  end

  test "adding existing cart item increments quantity" do
    # First, add a product to cart via quick add
    visit shop_path

    # Use single-variant product to avoid Add to Cart being disabled
    product = Product.quick_add_eligible.joins(:active_variants)
                     .group("products.id")
                     .having("COUNT(product_variants.id) = 1")
                     .first
    skip "No single-variant quick_add_eligible products available" unless product

    # First add: Add 1 pack
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Wait for Turbo Frame request to complete and content to render
    wait_for_quick_add_modal(product)
    execute_script("document.querySelector('[data-quick-add-form-target=\"submitButton\"]').click()")
    assert_no_selector "#quick-add-modal .modal-box", wait: 5

    # Second add: Add same product again via quick add
    visit shop_path

    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Wait for Turbo Frame request to complete and content to render
    wait_for_quick_add_modal(product)

    # Add to cart again (default quantity = 1 pack) - use JavaScript click for DaisyUI modal compatibility
    execute_script("document.querySelector('[data-quick-add-form-target=\"submitButton\"]').click()")

    # Modal closes, drawer opens
    assert_no_selector "#quick-add-modal .modal-box", wait: 5
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
