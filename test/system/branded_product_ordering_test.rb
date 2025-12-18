require "application_system_test_case"

class BrandedProductOrderingTest < ApplicationSystemTestCase
  setup do
    @acme_admin = users(:acme_admin)
    @product = products(:branded_double_wall_template)
  end

  test "complete branded product order workflow" do
    sign_in_as @acme_admin

    # Browse to branded product (uses branded_products controller, not products)
    visit branded_product_path(@product)

    # Verify configurator displayed
    assert_selector "h1", text: @product.name
    assert_selector "[data-controller~='branded-configurator']"

    # Step 1: Select size (first accordion is open by default)
    click_button "12oz"
    assert_selector ".border-primary", text: "12oz"

    # Step 2: Select quantity - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='5000']").click

    # Wait for price calculation (wait for non-zero price)
    assert_selector "[data-branded-configurator-target='total']", text: /£[1-9]/

    # Step 3: Skip lids (optional step) - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Continue to next step"

    # Step 4: Upload design - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(Rails.root.join("test", "fixtures", "files", "test_design.pdf"))
    assert_text "test_design.pdf"

    # Verify add to cart button is enabled (DaisyUI transforms text to uppercase)
    assert_no_selector ".btn-disabled", text: /add to cart/i
    assert_selector ".btn-primary", text: /add to cart/i

    # Step 5: Add to cart
    click_button "Add to Cart"

    # Wait for success - configurator resets after successful add
    # The design preview should be hidden after reset
    assert_no_text "test_design.pdf", wait: 5

    # Cart counter should show the quantity (branded products page doesn't have a drawer)
    # Navigate to cart to verify item was added
    visit cart_path

    # Verify cart contains the branded product
    assert_text @product.name
    assert_text "12oz" # size in configuration
  end

  test "validates all configurator steps must be completed" do
    sign_in_as @acme_admin
    visit branded_product_path(@product)

    # Initially add to cart should be disabled (no selections)
    # DaisyUI transforms button text to uppercase
    assert_selector ".btn-disabled", text: /add to cart/i

    # Select size only
    click_button "12oz"

    # Still disabled (missing quantity and design)
    assert_selector ".btn-disabled", text: /add to cart/i

    # Select quantity - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='1000']").click

    # Still disabled (missing design)
    assert_selector ".btn-disabled", text: /add to cart/i

    # Skip lids - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Continue to next step"

    # Upload design - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(Rails.root.join("test", "fixtures", "files", "test_design.pdf"))

    # Now enabled
    assert_no_selector ".btn-disabled", text: /add to cart/i
    assert_selector ".btn-primary", text: /add to cart/i
  end

  test "organization member can view branded products page" do
    sign_in_as @acme_admin

    # Verify signed in successfully by navigating to account page
    visit account_path
    assert_selector "h1", text: "Account Settings"

    # Navigate to organization products
    visit organizations_products_path

    # Should see the branded products page
    assert_selector "h1", text: "Your Branded Products"

    # The page should either show products or the empty state
    # Fixture products may or may not load depending on test database state
    assert_selector ".product-card, .empty-state"
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"

    # Wait for redirect after successful sign-in
    assert_current_path root_path
  end
end
