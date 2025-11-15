require "application_system_test_case"

class AdminProductDescriptionsTest < ApplicationSystemTestCase
  setup do
    @product = products(:one)
  end

  test "admin form displays three description fields" do
    visit edit_admin_product_path(@product)

    # Should see three separate textarea fields
    assert_selector "label", text: /Short Description/
    assert_selector "label", text: /Standard Description/
    assert_selector "label", text: /Detailed Description/

    assert_selector "textarea#product_description_short"
    assert_selector "textarea#product_description_standard"
    assert_selector "textarea#product_description_detailed"
  end

  test "admin form shows real-time character counters" do
    visit edit_admin_product_path(@product)

    # Find the short description textarea
    short_textarea = find("textarea#product_description_short")

    # Type some text
    short_textarea.fill_in with: "This is a test description"

    # Should see character counter update
    # Counter shows word count, not character count
    assert_selector "[data-character-counter-target='counter']", text: /\d+ words/
  end

  test "character counters show color-coded feedback" do
    visit edit_admin_product_path(@product)

    short_textarea = find("textarea#product_description_short")

    # Type text in target range (10-25 words) - should be green
    short_textarea.fill_in with: "This is exactly fifteen words of text to test the green color coding properly here"

    # Should have green color class (within range)
    assert_selector "[data-character-counter-target='counter'].text-green-600"
  end

  test "admin can save all three description fields" do
    visit edit_admin_product_path(@product)

    fill_in "product_description_short", with: "New short description"
    fill_in "product_description_standard", with: "New standard description text"
    fill_in "product_description_detailed", with: "New detailed description with comprehensive information"

    click_button "Update Product"

    # Should redirect to admin products index with success message
    assert_text "Product was successfully updated"

    # Verify data persisted
    @product.reload
    assert_equal "New short description", @product.description_short
    assert_equal "New standard description text", @product.description_standard
    assert_equal "New detailed description with comprehensive information", @product.description_detailed
  end

  test "admin can leave description fields blank" do
    visit edit_admin_product_path(@product)

    fill_in "product_description_short", with: ""
    fill_in "product_description_standard", with: ""
    fill_in "product_description_detailed", with: ""

    click_button "Update Product"

    # Should save successfully
    assert_text "Product was successfully updated"

    # Verify blank fields persisted
    @product.reload
    assert_nil @product.description_short
    assert_nil @product.description_standard
    assert_nil @product.description_detailed
  end
end
