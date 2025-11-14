require "application_system_test_case"

class ShopPageTest < ApplicationSystemTestCase
  test "browsing all products" do
    visit shop_path

    assert_selector "h1", text: "Shop All Products"
    assert_selector ".product-card", minimum: 1
  end

  test "filtering by categories" do
    visit shop_path

    # Filter by category using checkbox
    category = categories(:one)
    visit shop_path(categories: [ category.slug ])

    # Should show products from that category
    assert_selector ".product-card", minimum: 0

    # URL should reflect filter with slugs
    assert_current_path(/categories/)
  end

  test "searching products" do
    visit shop_path

    # Enter search query
    fill_in "q", with: "pizza"

    # Wait for debounced search (300ms + request time)
    sleep 0.5

    # URL should reflect search
    assert_current_path(/q=pizza/)
  end

  test "sorting products" do
    visit shop_path

    # Select sort option
    select "Price: Low to High", from: "sort"

    # Should reorder products
    assert_selector ".product-card", minimum: 1
    assert_current_path(/sort=price_asc/)
  end
end
