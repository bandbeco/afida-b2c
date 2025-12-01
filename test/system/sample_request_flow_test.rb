require "application_system_test_case"

class SampleRequestFlowTest < ApplicationSystemTestCase
  setup do
    @category = categories(:cups_and_lids)
    @sample_variant = product_variants(:sample_cup_8oz)
  end

  test "user can browse samples page" do
    visit samples_path

    assert_text "Request Free Samples"
    assert_text @category.name
  end

  test "user can expand category to see variants" do
    visit samples_path

    # Click on the category card
    click_on @category.name

    # Wait for Turbo Frame to load
    assert_selector "[data-category-expand-target='content']"
  end

  test "user can add sample to cart" do
    visit samples_path

    # Expand category
    click_on @category.name

    # Wait for content to load
    sleep 0.5

    # Find and click the Add Sample button
    within first(".card", text: @sample_variant.product.name) do
      click_on "Add Sample"
    end

    # Should show the sample counter
    assert_selector "#sample_counter"
    assert_text "1 / 5"
  end

  test "user can remove sample from cart" do
    # First add a sample
    visit samples_path
    click_on @category.name
    sleep 0.5

    within first(".card", text: @sample_variant.product.name) do
      click_on "Add Sample"
    end

    # Wait for update
    sleep 0.5

    # Click on "Added" to remove
    within first(".card", text: @sample_variant.product.name) do
      click_on "Added"
    end

    # Counter should update or hide
    assert_no_text "1 / 5"
  end

  test "sample counter shows limit reached message" do
    # Create a cart with 5 samples
    cart = Cart.create!
    5.times do |i|
      variant = ProductVariant.create!(
        product: @sample_variant.product,
        name: "Test Variant #{i}",
        sku: "TEST-SAMPLE-#{i}-#{SecureRandom.hex(4)}",
        price: 10.0,
        stock_quantity: 100,
        active: true,
        sample_eligible: true
      )
      cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0)
    end

    # Set the cart in the session
    page.set_rack_session(cart_id: cart.id)

    visit samples_path

    assert_text "5 / 5"
    assert_text "Sample limit reached"
  end

  test "cannot add more than 5 samples" do
    # Create cart with 5 samples
    cart = Cart.create!
    5.times do |i|
      variant = ProductVariant.create!(
        product: @sample_variant.product,
        name: "Test Variant #{i}",
        sku: "TEST-SAMPLE-LIMIT-#{i}-#{SecureRandom.hex(4)}",
        price: 10.0,
        stock_quantity: 100,
        active: true,
        sample_eligible: true
      )
      cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0)
    end

    page.set_rack_session(cart_id: cart.id)

    visit samples_path
    click_on @category.name
    sleep 0.5

    # Buttons should show "Limit Reached" for non-added variants
    assert_selector "button:disabled", text: "Limit Reached"
  end

  test "view cart link in counter navigates to cart" do
    visit samples_path
    click_on @category.name
    sleep 0.5

    within first(".card", text: @sample_variant.product.name) do
      click_on "Add Sample"
    end

    sleep 0.5

    click_on "View Cart"

    assert_current_path cart_path
  end
end
