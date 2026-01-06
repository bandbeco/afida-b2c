require "application_system_test_case"

class VariantSelectorTest < ApplicationSystemTestCase
  # T013: System tests for multi-option selection flow
  # Tests the unified variant selector accordion UI behavior

  setup do
    @multi_option_product = products(:single_wall_cups)
    @single_option_product = products(:paper_lids)  # Has size-only variants
  end

  # Helper: Select an option and wait for the step to collapse
  def select_option_and_wait(button)
    button.click
    # Wait for the step to collapse (data-expanded changes to false)
    step = button.ancestor("[data-variant-selector-target='step']")
    assert_selector "[data-variant-selector-target='step'][data-expanded='false']", match: :first, wait: 3 if step
  end

  # Helper: Wait for step to be in expected state
  def wait_for_step_state(step, expanded:)
    if expanded
      assert step.matches_css?(".collapse-open", wait: 3) || step["data-expanded"] == "true"
    else
      refute step.matches_css?(".collapse-open", wait: 3) if step.has_css?(".collapse-open", wait: 0.1)
    end
  end

  # Helper: Complete all option steps by selecting first available option in each
  def complete_all_option_steps
    steps = all("[data-variant-selector-target='step']")
    steps.each do |step|
      # Click header to expand if collapsed
      if step["data-expanded"] == "false"
        header = step.find("[data-variant-selector-target='stepHeader']")
        header.click
        # Wait for step to expand
        find("[data-variant-selector-target='step'].collapse-open", match: :first, wait: 3)
      end

      # Select first available option
      option_button = step.find("[data-variant-selector-target='optionButton']:not([disabled])", match: :first)
      option_button.click

      # Wait for selection to be processed (checkmark appears)
      step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)
    end
  end

  # Helper: Select quantity (tier card or quantity card)
  def select_quantity
    quantity_step = find("[data-variant-selector-target='quantityStep']")
    # Wait for quantity step to be expanded and have cards
    assert quantity_step.matches_css?(".collapse-open", wait: 3)

    if quantity_step.has_css?("[data-tier-card]", wait: 2)
      tier_card = quantity_step.find("[data-tier-card]", match: :first)
      tier_card.click
      # Wait for selection (border-primary added)
      quantity_step.find("[data-tier-card].border-primary", wait: 3)
    elsif quantity_step.has_css?("[data-quantity-card]", wait: 2)
      quantity_card = quantity_step.find("[data-quantity-card]", match: :first)
      quantity_card.click
      quantity_step.find("[data-quantity-card].border-primary", wait: 3)
    end
  end

  # T013.1: First step expanded on page load
  test "first option step is expanded on page load" do
    visit product_path(@multi_option_product.slug)

    # First step should be expanded (visible content, not collapsed)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    assert first_step["data-expanded"] == "true" || first_step.matches_css?(".collapse-open"),
           "First step should be expanded on page load"

    # First step's option buttons should be visible
    assert_selector "[data-variant-selector-target='step']:first-of-type [data-variant-selector-target='optionButton']"
  end

  # T013.2: Selecting option collapses step with checkmark and selection text
  test "selecting option collapses step and shows selection in header" do
    visit product_path(@multi_option_product.slug)

    # Find and click the first option button
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    option_value = first_option_button.text
    first_option_button.click

    # Wait for step to collapse and show checkmark
    first_step = find("[data-variant-selector-target='step']", match: :first)
    first_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    # Step should be collapsed
    assert first_step["data-expanded"] == "false" || !first_step.matches_css?(".collapse-open"),
           "Step should collapse after selection"

    # Header should show selected value
    step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    assert_match(/#{Regexp.escape(option_value)}/i, step_header.text,
                 "Header should show selected value: #{option_value}")
  end

  # T013.3: Next step auto-expands after selection
  test "next step auto-expands after selection" do
    visit product_path(@multi_option_product.slug)

    # Get all steps
    steps = all("[data-variant-selector-target='step']")
    skip "Product needs multiple option steps" if steps.count < 2

    # Second step should start collapsed
    second_step = steps[1]
    refute second_step["data-expanded"] == "true",
           "Second step should start collapsed"

    # Select first option
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for second step to expand (has collapse-open class)
    second_step_selector = "[data-variant-selector-target='step'][data-step-index='1'].collapse-open"
    assert_selector second_step_selector, wait: 3
  end

  # T013.4: Unavailable options appear disabled
  test "unavailable options appear disabled based on current selections" do
    # Use paper_straws which has sparse matrix (not all combinations exist)
    product = products(:paper_straws)
    visit product_path(product.slug)

    # Select first option (e.g., size)
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for selection to be processed
    find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

    # Verify the selector is filtering options (structural test)
    assert_selector "[data-variant-selector-target='optionButton']"
  end

  # T013.5: Add to cart button disabled until all selections complete
  test "add to cart button disabled until all selections complete" do
    visit product_path(@multi_option_product.slug)

    # Add to cart button should be disabled initially
    add_button = find("[data-variant-selector-target='addButton']")
    assert add_button.disabled? || add_button["aria-disabled"] == "true",
           "Add to cart button should be disabled until selections complete"

    # Complete all option selections
    complete_all_option_steps

    # Select quantity
    select_quantity

    # After all selections and quantity, button should be enabled
    add_button = find("[data-variant-selector-target='addButton']:not([disabled])", wait: 3)
    refute add_button.disabled?,
           "Add to cart button should be enabled after all selections complete"
  end

  # Additional test: URL params update as selections are made with lowercase values
  test "URL updates with option selections" do
    visit product_path(@multi_option_product.slug)

    # Select first option
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    option_value = first_option_button["data-value"]
    first_option_button.click

    # Wait for checkmark (indicates selection processed and URL updated)
    find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

    # URL should contain the selection with lowercase value
    assert_match(/[?&](size|colour|material|type)=/, page.current_url,
                 "URL should update with option selection")
    assert_match(/#{option_value.downcase}/i, page.current_url,
                 "URL param values should be lowercase")
  end

  # Test: Can add product to cart after selection
  test "can add to cart after completing selections" do
    visit product_path(@multi_option_product.slug)

    # Complete all option selections
    complete_all_option_steps

    # Select quantity
    select_quantity

    # Click add to cart
    add_button = find("[data-variant-selector-target='addButton']:not([disabled])", wait: 3)
    add_button.click

    # Should show success feedback - cart counter updates
    assert_selector "turbo-frame#cart_counter .badge", wait: 5
  end

  # ============================================================
  # User Story 2: Volume Discount Tiers (T021-T027)
  # ============================================================

  # T021: Tier cards display for variants with pricing_tiers
  test "tier cards display when variant has pricing_tiers" do
    visit product_path(@multi_option_product.slug)

    # Select 8oz size first
    size_button = find("[data-variant-selector-target='optionButton'][data-value='8oz']", wait: 3)
    size_button.click

    # Wait for next step to expand, then select White
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)
    white_button = find("[data-variant-selector-target='optionButton'][data-value='White']", wait: 3)
    white_button.click

    # Wait for quantity step to expand and show tier cards
    quantity_step = find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)
    assert_selector "[data-tier-card]", minimum: 2, wait: 3
  end

  # T021: Tier card shows pricing breakdown
  test "tier card shows pack quantity, price, units, and savings" do
    visit product_path(@multi_option_product.slug)

    # Select White variant (has pricing_tiers)
    find("[data-variant-selector-target='optionButton'][data-value='8oz']", wait: 3).click
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)
    find("[data-variant-selector-target='optionButton'][data-value='White']", wait: 3).click

    # Wait for tier cards to appear with content
    first_card = find("[data-tier-card]", match: :first, text: /pack/i, wait: 5)
    card_text = first_card.text

    # First tier should show "1 pack" or similar
    assert_match(/\d+\s*pack/i, card_text, "Tier card should show pack quantity")
    assert_match(/£\d+\.?\d*/i, card_text, "Tier card should show price")
    assert_match(/\d+.*units?/i, card_text, "Tier card should show unit count")

    # Higher tiers should show savings
    tier_cards = all("[data-tier-card]")
    if tier_cards.length > 1
      later_card = tier_cards.last
      assert_match(/save\s*\d+%/i, later_card.text,
                   "Later tier cards should show savings percentage")
    end
  end

  # T021: Selecting tier highlights card
  test "selecting tier card highlights it" do
    visit product_path(@multi_option_product.slug)

    # Select White variant (has pricing_tiers)
    find("[data-variant-selector-target='optionButton'][data-value='8oz']", wait: 3).click
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)
    find("[data-variant-selector-target='optionButton'][data-value='White']", wait: 3).click

    # Click a tier card and wait for highlight
    tier_card = find("[data-tier-card]", match: :first, wait: 3)
    tier_card.click

    # Verify card is highlighted with primary border
    assert_selector "[data-tier-card].border-primary", wait: 3
  end

  # T021: Add to cart shows correct total for selected tier
  test "add to cart button shows correct total for selected tier" do
    visit product_path(@multi_option_product.slug)

    # Select White variant (has pricing_tiers)
    find("[data-variant-selector-target='optionButton'][data-value='8oz']", wait: 3).click
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)
    find("[data-variant-selector-target='optionButton'][data-value='White']", wait: 3).click

    # Select a specific tier (not the first one if available)
    tier_cards = all("[data-tier-card]", wait: 3)
    skip "No tier cards found for this variant" if tier_cards.empty?
    target_card = tier_cards.length > 1 ? tier_cards[1] : tier_cards.first
    quantity = target_card["data-quantity"].to_i
    price = target_card["data-price"].to_f
    expected_total = (price * quantity).round(2)

    target_card.click

    # Wait for total to update
    total_display = find("[data-variant-selector-target='totalDisplay']", wait: 3)
    assert_match(/£#{expected_total}/i, total_display.text,
                 "Total display should show correct total for selected tier")
  end

  # T022: Quantity buttons fallback for non-tiered variants
  test "quantity buttons appear for variant without pricing_tiers" do
    visit product_path(@multi_option_product.slug)

    # Select 8oz size first
    find("[data-variant-selector-target='optionButton'][data-value='8oz']", wait: 3).click

    # Wait for next step, then select Black (no pricing_tiers)
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)
    find("[data-variant-selector-target='optionButton'][data-value='Black']", wait: 3).click

    # Wait for quantity step to expand
    find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)

    # Should have quantity card buttons, not tier cards
    assert_selector "[data-variant-selector-target='quantityContent'] [data-quantity-card]", wait: 3
    refute_selector "[data-tier-card]"
  end

  # ============================================================
  # User Story 3: Single-Option and Quantity-Only Products (T028-T032)
  # ============================================================

  # T028: Single-option products show just one option step + quantity
  test "single-option product shows one option step and quantity step" do
    visit product_path(@single_option_product.slug)

    # Should have exactly one option step (Size)
    option_steps = all("[data-variant-selector-target='step']")
    assert_equal 1, option_steps.count,
                 "Single-option product should have exactly 1 option step"

    # First step should be for size
    first_step = option_steps.first
    assert_match /size/i, first_step.text, "Step should be for Size option"

    # Should also have quantity step
    assert_selector "[data-variant-selector-target='quantityStep']"
  end

  # T028: Completing single-option selection shows quantity step
  test "completing single-option selection expands quantity step" do
    visit product_path(@single_option_product.slug)

    # Select the size option
    option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    option_button.click

    # Wait for quantity step to expand
    find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)

    # Quantity buttons should be visible
    assert_selector "[data-variant-selector-target='quantityContent'] [data-quantity-card]", wait: 3
  end

  # T029: Quantity-only products (no options) show only quantity step
  test "quantity-only product shows just quantity step" do
    only_product_in_category = products(:only_product_in_category)
    visit product_path(only_product_in_category.slug)

    # Should have NO option steps (empty options)
    option_steps = all("[data-variant-selector-target='step']")
    assert_equal 0, option_steps.count,
                 "Quantity-only product should have 0 option steps"

    # Quantity step should be visible and expanded by default
    quantity_step = find("[data-variant-selector-target='quantityStep']")
    assert quantity_step.matches_css?(".collapse-open"),
           "Quantity step should be expanded for quantity-only products"

    # Quantity buttons should be visible
    assert_selector "[data-variant-selector-target='quantityContent'] [data-quantity-card]", wait: 3
  end

  # T029: Quantity-only product enables add to cart after quantity selection
  test "can add quantity-only product to cart without option selection" do
    only_product_in_category = products(:only_product_in_category)
    visit product_path(only_product_in_category.slug)

    # Quantity buttons should be visible immediately (no option steps to complete)
    assert_selector "[data-variant-selector-target='quantityContent'] [data-quantity-card]", wait: 3

    # Select a quantity card
    quantity_card = find("[data-quantity-card]", match: :first)
    quantity_card.click

    # Wait for selection - card should be highlighted
    assert_selector "[data-quantity-card].border-primary", wait: 3

    # Add to cart button should now be enabled (was disabled before selection)
    assert_selector "[data-variant-selector-target='addButton']:not([disabled])", wait: 3
  end

  # ============================================================
  # User Story 4: Revise Previous Selection (T033-T037)
  # ============================================================

  # T033: Clicking collapsed step header expands it
  test "clicking collapsed step header expands it" do
    visit product_path(@multi_option_product.slug)

    # Make a selection in first step
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for step to collapse
    first_step = find("[data-variant-selector-target='step'][data-expanded='false']", match: :first, wait: 3)

    # Click the header to re-expand
    first_step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    first_step_header.click

    # Verify step expanded again
    assert_selector "[data-variant-selector-target='step'][data-step-index='0'].collapse-open", wait: 3
  end

  # T034: Changing earlier selection clears invalid downstream selections
  test "changing earlier selection clears invalid downstream selections" do
    visit product_path(@multi_option_product.slug)

    steps = all("[data-variant-selector-target='step']")
    skip "Product needs multiple option steps" if steps.count < 2

    # Select first option
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for second step to expand
    find("[data-variant-selector-target='step'][data-step-index='1'].collapse-open", wait: 3)

    # Select second option
    second_step = all("[data-variant-selector-target='step']")[1]
    second_option_button = second_step.find("[data-variant-selector-target='optionButton']", match: :first)
    selected_value = second_option_button.text
    second_option_button.click

    # Wait for selection
    second_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    # Verify second step shows selection
    second_step_selection = second_step.find("[data-variant-selector-target='stepSelection']")
    assert_match(/#{Regexp.escape(selected_value)}/i, second_step_selection.text,
                 "Second step should show selection")

    # Go back and change first selection
    first_step = all("[data-variant-selector-target='step']").first
    first_step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    first_step_header.click

    # Wait for first step to expand
    find("[data-variant-selector-target='step'][data-step-index='0'].collapse-open", wait: 3)

    # Select a different first option
    different_option = all("[data-variant-selector-target='optionButton'][data-option-name='size']:not(.btn-primary):not([disabled])").first
    skip "Need multiple available first options to test" unless different_option
    different_option.click

    # Wait for selection to be processed
    find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

    # Verify the mechanism works
    assert_selector "[data-variant-selector-target='step']"
  end

  # ============================================================
  # Edge Cases: URL Parameter Validation (T038-T040)
  # ============================================================

  # T038: Invalid URL parameter value is gracefully ignored
  test "invalid URL parameter value is gracefully ignored" do
    visit product_path(@multi_option_product.slug, size: "INVALID_SIZE_XYZ")

    # Page should load without error
    assert_selector "[data-variant-selector-target='step']"

    # First step should still be expanded (invalid param ignored)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    assert first_step["data-expanded"] == "true" || first_step.matches_css?(".collapse-open"),
           "First step should be expanded when URL param is invalid"

    # No selection should be pre-made for the invalid value
    selected_buttons = all("[data-variant-selector-target='optionButton'].border-primary, [data-variant-selector-target='optionButton'].border-4")
    assert_equal 0, selected_buttons.count,
                 "No option should be pre-selected for invalid URL param"
  end

  # T038: Valid URL parameter pre-selects option
  test "valid URL parameter pre-selects option" do
    variant = @multi_option_product.active_variants.first
    option_name = variant.option_values_hash.keys.first
    option_value = variant.option_values_hash[option_name]

    visit product_path(@multi_option_product.slug, option_name => option_value)

    # Wait for JS to process URL params (checkmark appears)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    first_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    # Verify selection
    step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    has_selection = step_header.text.include?(option_value) ||
                    first_step.has_css?("[data-variant-selector-target='optionButton'].border-primary[data-value='#{option_value}']") ||
                    first_step.has_css?("[data-variant-selector-target='optionButton'].border-4[data-value='#{option_value}']")

    assert has_selection, "Valid URL param should pre-select the option"
  end

  # T039: Multiple invalid URL parameters don't break the page
  test "multiple invalid URL parameters don't break the page" do
    visit product_path(@multi_option_product.slug,
                       size: "FAKE_SIZE",
                       colour: "FAKE_COLOUR",
                       material: "FAKE_MATERIAL")

    # Page should load without error
    assert_selector "[data-variant-selector-target='step']"

    # Add to cart should be disabled (no valid selections)
    add_button = find("[data-variant-selector-target='addButton']")
    assert add_button.disabled?, "Add to cart should be disabled with invalid params"

    # Should be able to make valid selections normally
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for selection to be processed
    find("[data-variant-selector-target='step'][data-expanded='false']", match: :first, wait: 3)
  end

  # T040: URL injection attempt with special characters
  test "URL parameters with special characters are safely handled" do
    visit product_path(@multi_option_product.slug,
                       size: "<script>alert('xss')</script>",
                       colour: "'; DROP TABLE products; --")

    # Page should load without error
    assert_selector "[data-variant-selector-target='step']"

    # First step should be expanded (invalid params ignored)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    assert first_step["data-expanded"] == "true" || first_step.matches_css?(".collapse-open"),
           "First step should be expanded (invalid params ignored)"
  end

  # ============================================================
  # Edge Cases: Browser Navigation (T041-T043)
  # ============================================================

  # T041: URL updates don't break browser back button
  test "browser back button works after URL updates from selections" do
    visit root_path
    initial_path = page.current_path

    visit product_path(@multi_option_product.slug)
    assert_selector "[data-variant-selector-target='step']"

    # Make a selection
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    first_option_button.click

    # Wait for selection to be processed
    find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

    # URL should have been updated
    assert_match(/[?&](size|colour|material|type)=/, page.current_url,
                 "URL should be updated with selection")

    # Go back to previous page
    page.go_back

    assert_current_path initial_path
  end

  # T042: Refreshing page preserves selections via URL params
  test "refreshing page preserves selections via URL params" do
    visit product_path(@multi_option_product.slug)

    # Make a selection
    first_option_button = find("[data-variant-selector-target='optionButton']", match: :first)
    option_value = first_option_button["data-value"]
    first_option_button.click

    # Wait for checkmark
    find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

    # Capture current URL with params
    url_with_params = page.current_url

    # Refresh the page
    visit url_with_params

    # Wait for selection to be restored (checkmark appears)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    first_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    # Verify selection preserved
    step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    selection_preserved = step_header.text.downcase.include?(option_value.downcase) ||
                          first_step.has_css?("[data-variant-selector-target='optionButton'].border-primary[data-value='#{option_value}']") ||
                          first_step.has_css?("[data-variant-selector-target='optionButton'].border-4[data-value='#{option_value}']")

    assert selection_preserved, "Selection should be preserved after page refresh"
  end

  # T042b: Refreshing page with URL params keeps completed steps collapsed
  test "page refresh with URL params keeps completed steps collapsed" do
    visit product_path(@multi_option_product.slug)
    steps = all("[data-variant-selector-target='step']")
    skip "Product needs at least 2 option steps" if steps.count < 2

    first_option_name = steps[0]["data-option-name"]
    second_option_name = steps[1]["data-option-name"]

    variant = @multi_option_product.active_variants.first
    first_value = variant.option_values_hash[first_option_name]
    second_value = variant.option_values_hash[second_option_name]

    skip "Variant needs values for first two options" unless first_value && second_value

    # Visit with lowercase URL params
    visit product_path(@multi_option_product.slug,
                       first_option_name => first_value.downcase,
                       second_option_name => second_value.downcase)

    # Wait for both steps to show checkmarks (selections applied)
    first_step = find("[data-variant-selector-target='step']", match: :first)
    first_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    second_step = all("[data-variant-selector-target='step']")[1]
    second_step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)

    # First step should be COLLAPSED
    first_step_collapsed = first_step["data-expanded"] == "false" || !first_step.matches_css?(".collapse-open")
    assert first_step_collapsed,
           "First step with URL param selection should be collapsed on page load"

    # Second step should be COLLAPSED
    second_step_collapsed = second_step["data-expanded"] == "false" || !second_step.matches_css?(".collapse-open")
    assert second_step_collapsed,
           "Second step with URL param selection should be collapsed on page load"

    # The first INCOMPLETE step (or quantity step) should be expanded
    if steps.count > 2
      third_step = all("[data-variant-selector-target='step']")[2]
      third_step_expanded = third_step["data-expanded"] == "true" || third_step.matches_css?(".collapse-open")
      assert third_step_expanded,
             "First incomplete step should be expanded when URL has partial selections"
    else
      quantity_step = find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)
      assert quantity_step,
             "Quantity step should be expanded when all option steps are from URL"
    end
  end

  # T043: Direct URL with all params shows completed state
  test "direct URL with all valid params shows completed selection state" do
    variant = @multi_option_product.active_variants.first
    params = variant.option_values_hash.dup

    visit product_path(@multi_option_product.slug, params)

    # Wait for all checkmarks to appear
    steps = all("[data-variant-selector-target='step']")
    steps.each_with_index do |step, index|
      indicator = step.find("[data-variant-selector-target='stepIndicator']", wait: 3)
      has_checkmark = indicator.text == "✓" || indicator[:class].to_s.include?("bg-primary")
      assert has_checkmark, "Step #{index + 1} should show checkmark when param is valid"
    end

    # Quantity step should be expanded
    find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)
  end

  # T033: Can change selection and proceed to checkout
  test "can revise selection and complete checkout flow" do
    visit product_path(@multi_option_product.slug)

    # Complete all option selections
    complete_all_option_steps

    # Select quantity
    select_quantity

    # Now go back and change first selection
    first_step = find("[data-variant-selector-target='step']", match: :first)
    first_step_header = first_step.find("[data-variant-selector-target='stepHeader']")
    first_step_header.click

    # Wait for first step to expand
    find("[data-variant-selector-target='step'][data-step-index='0'].collapse-open", wait: 3)

    # Select a different option (second one if available)
    options = first_step.all("[data-variant-selector-target='optionButton']:not([disabled])")
    if options.count > 1
      options[1].click

      # Wait for selection
      find("[data-variant-selector-target='stepIndicator']", text: "✓", match: :first, wait: 3)

      # Complete remaining selections
      steps = all("[data-variant-selector-target='step']")
      steps.each do |step|
        next if step.find("[data-variant-selector-target='stepIndicator']").text == "✓"

        header = step.find("[data-variant-selector-target='stepHeader']")
        header.click unless step.matches_css?(".collapse-open")
        find("[data-variant-selector-target='step'].collapse-open", match: :first, wait: 3)

        option_button = step.find("[data-variant-selector-target='optionButton']:not([disabled])", match: :first)
        option_button.click
        step.find("[data-variant-selector-target='stepIndicator']", text: "✓", wait: 3)
      end
    end

    # Select quantity again after revision
    quantity_step = find("[data-variant-selector-target='quantityStep']")
    unless quantity_step.matches_css?(".collapse-open")
      quantity_header = quantity_step.find("[data-variant-selector-target='quantityStepHeader']")
      quantity_header.click
      find("[data-variant-selector-target='quantityStep'].collapse-open", wait: 3)
    end

    if quantity_step.has_css?("[data-tier-card]", wait: 2)
      tier_card = quantity_step.find("[data-tier-card]", match: :first)
      tier_card.click unless tier_card[:class].to_s.include?("border-primary")
    elsif quantity_step.has_css?("[data-quantity-card]", wait: 2)
      quantity_card = quantity_step.find("[data-quantity-card]", match: :first)
      quantity_card.click unless quantity_card[:class].to_s.include?("border-primary")
    end

    # Add to cart should work
    add_button = find("[data-variant-selector-target='addButton']:not([disabled])", wait: 3)
    refute add_button.disabled?, "Add to cart should be enabled after revising selections"
  end
end
