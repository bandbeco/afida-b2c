require "application_system_test_case"

class SamplePackProductPageTest < ApplicationSystemTestCase
  setup do
    @sample_pack = products(:sample_pack)
    @variant = product_variants(:sample_pack_variant)
    @regular_product = products(:one)
  end

  test "sample pack product page hides quantity selector" do
    visit product_path(@sample_pack)

    # Should NOT have quantity selector
    assert_no_selector "select#cart_item_quantity"
    assert_no_selector "[data-product-options-target='quantitySelect']"
  end

  test "sample pack product page shows free price text" do
    visit product_path(@sample_pack)

    # Should show "Free" or "Free — just pay shipping" instead of £0.00
    assert_text(/Free/i)
    assert_no_text "£0.00"
  end

  test "regular product page still shows quantity selector" do
    visit product_path(@regular_product)

    # Regular products should have quantity selector
    assert_selector "select#cart_item_quantity, [data-product-options-target='quantitySelect']"
  end

  test "sample pack product page has add to cart button" do
    visit product_path(@sample_pack)

    # The "Add to cart" button should be visible (may be uppercase due to TailwindCSS btn class)
    assert_selector "input[type='submit']"
  end
end
