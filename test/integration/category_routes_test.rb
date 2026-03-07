require "test_helper"

class CategoryRoutesTest < ActionDispatch::IntegrationTest
  # =========================================================================
  # Nested subcategory routes: /categories/:parent_slug/:id
  # =========================================================================

  test "nested subcategory route renders subcategory page" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get "/categories/#{parent.slug}/#{subcategory.slug}"
    assert_response :success
    assert_match subcategory.name, response.body
  end

  test "nested subcategory route returns 404 for wrong parent" do
    subcategory = categories(:child_pizza_boxes)

    get "/categories/cups-and-drinks/#{subcategory.slug}"
    assert_response :not_found
  end

  test "nested subcategory route returns 404 for nonexistent subcategory" do
    parent = categories(:parent_hot_food)

    get "/categories/#{parent.slug}/nonexistent-slug"
    assert_response :not_found
  end

  # =========================================================================
  # Parent category routes: /categories/:id (top-level)
  # =========================================================================

  test "parent category route renders parent page with all subcategory products" do
    parent = categories(:parent_hot_food)

    get "/categories/#{parent.slug}"
    assert_response :success
    assert_match parent.name, response.body
  end

  # =========================================================================
  # Old category slug redirects (301) to new nested URLs
  # PRD Section 8: 301 Redirects Required
  # =========================================================================

  test "redirects /categories/cups-and-lids to /categories/cups-and-drinks" do
    get "/categories/cups-and-lids"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks"
  end

  test "redirects /categories/ice-cream-cups to /categories/cups-and-drinks/ice-cream-cups" do
    get "/categories/ice-cream-cups"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks/ice-cream-cups"
  end

  test "redirects /categories/napkins to /categories/tableware/napkins" do
    get "/categories/napkins"
    assert_response :moved_permanently
    assert_redirected_to "/categories/tableware/napkins"
  end

  test "redirects /categories/pizza-boxes to /categories/hot-food/pizza-boxes" do
    get "/categories/pizza-boxes"
    assert_response :moved_permanently
    assert_redirected_to "/categories/hot-food/pizza-boxes"
  end

  test "redirects /categories/straws to /categories/cups-and-drinks/straws" do
    get "/categories/straws"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks/straws"
  end

  test "redirects /categories/takeaway-containers to /categories/hot-food" do
    get "/categories/takeaway-containers"
    assert_response :moved_permanently
    assert_redirected_to "/categories/hot-food"
  end

  test "redirects /categories/takeaway-extras to /categories/supplies-and-essentials" do
    get "/categories/takeaway-extras"
    assert_response :moved_permanently
    assert_redirected_to "/categories/supplies-and-essentials"
  end

  test "old category redirects preserve query parameters" do
    get "/categories/ice-cream-cups?utm_source=google"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks/ice-cream-cups?utm_source=google"
  end

  # =========================================================================
  # Legacy /category/* redirects chain through to final new URLs
  # PRD Section 8: "Legacy /category/* redirects must be updated to chain
  # through to the new URLs instead of pointing to now-dead intermediate URLs"
  # =========================================================================

  test "legacy /category/napkins redirects to new nested URL" do
    get "/category/napkins"
    assert_response :moved_permanently
    assert_redirected_to "/categories/tableware/napkins"
  end

  test "legacy /category/pizza-boxes redirects to new nested URL" do
    get "/category/pizza-boxes"
    assert_response :moved_permanently
    assert_redirected_to "/categories/hot-food/pizza-boxes"
  end

  test "legacy /category/straws redirects to new nested URL" do
    get "/category/straws"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks/straws"
  end

  test "legacy /category/takeaway-containers redirects to new parent URL" do
    get "/category/takeaway-containers"
    assert_response :moved_permanently
    assert_redirected_to "/categories/hot-food"
  end

  test "legacy /category/takeaway-extras redirects to new parent URL" do
    get "/category/takeaway-extras"
    assert_response :moved_permanently
    assert_redirected_to "/categories/supplies-and-essentials"
  end

  test "legacy /category/cold-cups-lids redirects to cups-and-drinks" do
    get "/category/cold-cups-lids"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks"
  end

  test "legacy /category/hot-cups redirects to cups-and-drinks" do
    get "/category/hot-cups"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks"
  end

  test "legacy /category/hot-cup-extras redirects to cups-and-drinks" do
    get "/category/hot-cup-extras"
    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks"
  end

  test "legacy /category/all-products still redirects to shop" do
    get "/category/all-products"
    assert_response :moved_permanently
    assert_redirected_to "/shop"
  end

  test "legacy category redirect preserves query params" do
    get "/category/napkins?utm_source=google&utm_campaign=test"
    assert_response :moved_permanently
    assert_redirected_to "/categories/tableware/napkins?utm_source=google&utm_campaign=test"
  end

  # =========================================================================
  # URL helper: subcategory_path generates nested URL
  # =========================================================================

  test "subcategory route helper generates nested URL" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    assert_equal "/categories/#{parent.slug}/#{subcategory.slug}",
                 category_subcategory_path(parent.slug, subcategory.slug)
  end
end
