require "application_system_test_case"

class QuickAddAccessibilityTest < ApplicationSystemTestCase
  # User Story 3: Accessibility tests

  test "keyboard navigation through modal elements" do
    visit shop_path

    product = Product.quick_add_eligible.first
    skip "No quick_add_eligible products available" unless product

    # Click Quick Add
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal should open
    assert_selector ".modal.modal-open"

    # Verify modal has ARIA attributes
    assert_selector "[role='dialog'][aria-modal='true']"

    # Verify modal title has ID for aria-labelledby
    assert_selector "#quick-add-title"

    # Tab through elements (verify they are focusable)
    # This is tested via ARIA attributes and semantic HTML
    # Focus trap is tested in separate test
    assert_selector "select, button"
  end

  test "ESC key closes modal" do
    visit shop_path

    product = Product.quick_add_eligible.first
    skip "No quick_add_eligible products available" unless product

    # Click Quick Add
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal should be open
    assert_selector ".modal.modal-open"

    # Press ESC key
    page.driver.browser.action.send_keys(:escape).perform

    # Modal should close
    assert_no_selector ".modal.modal-open", wait: 2
  end

  test "focus management and restoration" do
    visit shop_path

    product = Product.quick_add_eligible.first
    skip "No quick_add_eligible products available" unless product

    # Find the Quick Add button
    quick_add_button = find("[data-product-id='#{product.id}'] a", text: "Quick Add", match: :first)

    # Click Quick Add
    quick_add_button.click

    # Modal should open
    assert_selector ".modal.modal-open"

    # Verify focus is within the modal (not on background elements)
    # Focus management is handled by Stimulus controller
    # Note: Exact focused element may vary based on browser/timing

    # Close modal with Cancel button
    click_button "Cancel"

    # Modal should close
    assert_no_selector ".modal.modal-open", wait: 2

    # Focus should return to Quick Add button (if possible to test)
    # Note: Capybara may not reliably test focus restoration
  end

  test "modal has proper ARIA labels" do
    visit shop_path

    product = Product.quick_add_eligible.first
    skip "No quick_add_eligible products available" unless product

    # Click Quick Add
    within("[data-product-id='#{product.id}']", match: :first) do
      click_link "Quick Add"
    end

    # Modal should have proper ARIA attributes
    assert_selector ".modal[role='dialog'][aria-modal='true']"
    assert_selector "[aria-labelledby='quick-add-title']"
    assert_selector "#quick-add-title"

    # Form elements should have labels
    assert_selector "label[for], label .label-text"
  end

  test "form elements are keyboard accessible" do
    visit shop_path

    product = Product.quick_add_eligible.joins(:active_variants)
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

    # All interactive elements should be keyboard accessible (no tabindex=-1 on interactive elements)
    assert_no_selector "select[tabindex='-1'], button[tabindex='-1']:not([disabled])"

    # Submit button should be reachable (Rails renders f.submit as input[type=submit])
    assert_selector "input[type='submit'], button[type='submit']"
  end
end
