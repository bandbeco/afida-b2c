require "test_helper"

# June 2026 admin category restructure (slugs renamed 2026-06-22..25) left the
# old URLs 404ing while Google still ranks them (SEO audit 2026-07-02,
# docs/reports/seo-audit-2026-07-02.md). These 301s preserve that equity.
class CategoryRenameRedirectsTest < ActionDispatch::IntegrationTest
  # cups-and-drinks → cups-and-accessories
  test "redirects renamed cups-and-drinks parent" do
    get "/categories/cups-and-drinks"
    assert_redirected_to "/categories/cups-and-accessories"
    assert_equal 301, response.status
  end

  test "redirects renamed cold-cups to cold-cups-and-lids" do
    get "/categories/cups-and-drinks/cold-cups"
    assert_redirected_to "/categories/cups-and-accessories/cold-cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-cups" do
    get "/categories/cups-and-drinks/hot-cups"
    assert_redirected_to "/categories/cups-and-accessories/hot-cups"
    assert_equal 301, response.status
  end

  test "redirects renamed ice-cream-cups" do
    get "/categories/cups-and-drinks/ice-cream-cups"
    assert_redirected_to "/categories/cups-and-accessories/ice-cream-cups"
    assert_equal 301, response.status
  end

  test "redirects renamed cup-lids" do
    get "/categories/cups-and-drinks/cup-lids"
    assert_redirected_to "/categories/cups-and-accessories/cup-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed cup-accessories" do
    get "/categories/cups-and-drinks/cup-accessories"
    assert_redirected_to "/categories/cups-and-accessories/cup-accessories"
    assert_equal 301, response.status
  end

  test "redirects renamed straws" do
    get "/categories/cups-and-drinks/straws"
    assert_redirected_to "/categories/cups-and-accessories/straws"
    assert_equal 301, response.status
  end

  test "redirects unknown cups-and-drinks children to the new parent" do
    get "/categories/cups-and-drinks/some-old-subcategory"
    assert_redirected_to "/categories/cups-and-accessories"
    assert_equal 301, response.status
  end

  test "redirects interim cups-and-accessories/cold-cups slug to cold-cups-and-lids" do
    get "/categories/cups-and-accessories/cold-cups"
    assert_redirected_to "/categories/cups-and-accessories/cold-cups-and-lids"
    assert_equal 301, response.status
  end

  # hot-food → food-containers
  test "redirects renamed hot-food parent" do
    get "/categories/hot-food"
    assert_redirected_to "/categories/food-containers"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food pizza-boxes" do
    get "/categories/hot-food/pizza-boxes"
    assert_redirected_to "/categories/food-containers/pizza-boxes"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food takeaway-boxes" do
    get "/categories/hot-food/takeaway-boxes"
    assert_redirected_to "/categories/food-containers/takeaway-boxes"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food soup-containers" do
    get "/categories/hot-food/soup-containers"
    assert_redirected_to "/categories/food-containers/soup-containers"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food bagasse-containers" do
    get "/categories/hot-food/bagasse-containers"
    assert_redirected_to "/categories/food-containers/bagasse-containers"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food food-containers to food-containers-and-lids" do
    get "/categories/hot-food/food-containers"
    assert_redirected_to "/categories/food-containers/food-containers-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food food-bowls to bowls-and-lids" do
    get "/categories/hot-food/food-bowls"
    assert_redirected_to "/categories/food-containers/bowls-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food round-containers-lids to food-containers-and-lids" do
    get "/categories/hot-food/round-containers-lids"
    assert_redirected_to "/categories/food-containers/food-containers-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food portion-pots-lids to portion-pots-and-lids" do
    get "/categories/hot-food/portion-pots-lids"
    assert_redirected_to "/categories/food-containers/portion-pots-and-lids"
    assert_equal 301, response.status
  end

  test "redirects unknown hot-food children to food-containers" do
    get "/categories/hot-food/some-old-subcategory"
    assert_redirected_to "/categories/food-containers"
    assert_equal 301, response.status
  end

  # One-off renames and moves
  test "redirects renamed deli-pots to deli-containers" do
    get "/categories/cold-food-and-salads/deli-pots"
    assert_redirected_to "/categories/cold-food-and-salads/deli-containers"
    assert_equal 301, response.status
  end

  test "redirects renamed plates-and-trays to plates-and-bowls" do
    get "/categories/tableware/plates-and-trays"
    assert_redirected_to "/categories/tableware/plates-and-bowls"
    assert_equal 301, response.status
  end

  test "redirects moved aluminium-containers from tableware to food-containers" do
    get "/categories/tableware/aluminium-containers"
    assert_redirected_to "/categories/food-containers/aluminium-containers"
    assert_equal 301, response.status
  end

  # Interim slug variants without "and" seen in traffic
  test "redirects portion-pots-lids slug variant" do
    get "/categories/food-containers/portion-pots-lids"
    assert_redirected_to "/categories/food-containers/portion-pots-and-lids"
    assert_equal 301, response.status
  end

  test "redirects bowls-lids slug variant" do
    get "/categories/food-containers/bowls-lids"
    assert_redirected_to "/categories/food-containers/bowls-and-lids"
    assert_equal 301, response.status
  end

  test "redirects food-containers-lids slug variant" do
    get "/categories/food-containers/food-containers-lids"
    assert_redirected_to "/categories/food-containers/food-containers-and-lids"
    assert_equal 301, response.status
  end

  # Collection pages scoped to a renamed category slug (GSC 404 report 2026-07-07)
  test "redirects vegware collection scoped to renamed hot-food slug" do
    get "/collections/vegware/hot-food"
    assert_redirected_to "/collections/vegware/food-containers"
    assert_equal 301, response.status
  end

  test "redirects vegware collection scoped to renamed cups-and-drinks slug" do
    get "/collections/vegware/cups-and-drinks"
    assert_redirected_to "/collections/vegware/cups-and-accessories"
    assert_equal 301, response.status
  end

  test "preserves query parameters on the vegware cups-and-drinks redirect" do
    get "/collections/vegware/cups-and-drinks?utm_source=google"
    assert_redirected_to "/collections/vegware/cups-and-accessories?utm_source=google"
  end

  # Query strings survive the redirect (UTM tracking)
  test "preserves query parameters on renamed category redirect" do
    get "/categories/cups-and-drinks/hot-cups?utm_source=google&utm_campaign=test"
    assert_redirected_to "/categories/cups-and-accessories/hot-cups?utm_source=google&utm_campaign=test"
  end

  test "preserves query parameters on the renamed-parent catch-all" do
    get "/categories/hot-food/some-old-subcategory?utm_source=google"
    assert_redirected_to "/categories/food-containers?utm_source=google"
  end
end
