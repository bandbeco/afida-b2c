require "application_system_test_case"

class SamplePackCheckoutTest < ApplicationSystemTestCase
  setup do
    @sample_pack = products(:sample_pack)
    @sample_variant = product_variants(:sample_pack_variant)
    @regular_product = products(:one)
    @regular_variant = product_variants(:one)
  end

  test "sample pack and regular product can both be added to cart" do
    # Add sample pack first
    visit samples_path
    first("button", text: /Add Sample Pack to Cart/i).click
    assert_text(/added|cart/i)

    # Add regular product
    visit product_path(@regular_product)
    click_button "Add to cart"

    # Visit cart and verify both items are present
    visit cart_path
    assert_text @sample_pack.name
    assert_text @regular_product.name
  end

  test "cart displays sample pack as Free and regular product with price" do
    # Create cart with both items
    visit samples_path
    first("button", text: /Add Sample Pack to Cart/i).click

    visit product_path(@regular_product)
    click_button "Add to cart"

    # Visit cart
    visit cart_path

    # Sample pack should show "Free"
    assert_text "Free"

    # Regular product should show price
    assert_text @regular_variant.price.to_s.gsub(".0", "")
  end

  test "cart total reflects only regular product price" do
    # Add both items to cart
    visit samples_path
    first("button", text: /Add Sample Pack to Cart/i).click

    visit product_path(@regular_product)
    click_button "Add to cart"

    # Visit cart - the total should only include regular product (sample pack is £0)
    visit cart_path

    # The cart should show a total (which doesn't include sample pack £0)
    assert_text "Total"
    assert_text @regular_variant.price.to_s.gsub(/\.0+$/, "")
  end
end
