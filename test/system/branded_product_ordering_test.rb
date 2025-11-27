require "application_system_test_case"

class BrandedProductOrderingTest < ApplicationSystemTestCase
  setup do
    @acme_admin = users(:acme_admin)
    @product = products(:branded_double_wall_template)
  end

  test "complete branded product order workflow" do
    sign_in_as @acme_admin

    # Browse to branded product
    visit product_path(@product)

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
    click_button "Skip - No lids needed"

    # Step 4: Upload design - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(Rails.root.join("test", "fixtures", "files", "test_design.pdf"))
    assert_text "test_design.pdf"

    # Verify add to cart button is enabled
    assert_no_selector ".btn-disabled", text: "Add to Cart"
    assert_selector ".btn-primary", text: "Add to Cart"

    # Step 5: Add to cart
    click_button "Add to Cart"

    # Navigate to cart to verify item was added
    visit cart_path
    assert_text @product.name
    assert_text "12oz" # size
    assert_text "5,000" # quantity
  end

  test "validates all configurator steps must be completed" do
    sign_in_as @acme_admin
    visit product_path(@product)

    # Initially add to cart should be disabled (no selections)
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Select size only
    click_button "12oz"

    # Still disabled (missing quantity and design)
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Select quantity - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='1000']").click

    # Still disabled (missing design)
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Skip lids - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Skip - No lids needed"

    # Upload design - open accordion by clicking hidden radio
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(Rails.root.join("test", "fixtures", "files", "test_design.pdf"))

    # Now enabled
    assert_no_selector ".btn-disabled", text: "Add to Cart"
    assert_selector ".btn-primary", text: "Add to Cart"
  end

  test "organization member can view and reorder branded products" do
    sign_in_as @acme_admin

    # Verify signed in successfully
    assert_no_selector ".btn", text: "Sign In"
    assert_text @acme_admin.email_address

    # Navigate to organization products
    visit organizations_products_path

    assert_selector "h1", text: "Your Branded Products"
    assert_selector ".product-card", count: 1 # acme_branded_cups

    # Click on product
    click_link products(:acme_branded_cups).name

    # Verify show page
    assert_text "12oz"
    assert_text products(:acme_branded_cups).active_variants.first.sku

    # Change quantity and add to cart
    fill_in "Quantity", with: 2000
    click_button "Add to Cart"

    # Verify in cart
    assert_current_path cart_path
    assert_text products(:acme_branded_cups).name
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"

    # Verify redirect after sign-in
    assert_no_selector "h1", text: "Sign In"
  end
end
