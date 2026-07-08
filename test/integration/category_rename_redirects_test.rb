require "test_helper"

# June 2026 admin category restructure (slugs renamed 2026-06-22..25): the old
# URLs still rank in Google, so they must 301, never 404.
#
# These redirects are data-driven: CategorySlugRedirect rows (fixtures here;
# backfill migration 20260708123508 in production) resolved by the
# categories/collections/samples controllers. This file tests each behaviour
# of that mechanism against the June renames. Per-URL coverage of every
# production rename lives in the backfill migration, not here; the fixture
# world only mirrors the cups-and-drinks and hot-food families.
class CategoryRenameRedirectsTest < ActionDispatch::IntegrationTest
  # Renamed top-level slugs
  test "redirects renamed cups-and-drinks parent" do
    get "/categories/cups-and-drinks"
    assert_redirected_to "/categories/cups-and-accessories"
    assert_equal 301, response.status
  end

  test "redirects renamed hot-food parent" do
    get "/categories/hot-food"
    assert_redirected_to "/categories/food-containers"
    assert_equal 301, response.status
  end

  # Renamed child slug, reached under the old parent, the new parent, or flat
  test "redirects renamed child under the renamed parent" do
    get "/categories/cups-and-drinks/cold-cups"
    assert_redirected_to "/categories/cups-and-accessories/cold-cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed child under the current parent" do
    get "/categories/cups-and-accessories/cold-cups"
    assert_redirected_to "/categories/cups-and-accessories/cold-cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects renamed child at the flat URL" do
    get "/categories/cold-cups"
    assert_redirected_to "/categories/cups-and-accessories/cold-cups-and-lids"
    assert_equal 301, response.status
  end

  # Live child reached under the renamed parent slug
  test "redirects live children of renamed parents to the canonical URL" do
    get "/categories/cups-and-drinks/hot-cups"
    assert_redirected_to "/categories/cups-and-accessories/hot-cups"
    assert_equal 301, response.status
  end

  # Unknown children of renamed parents fall back to the new parent
  test "redirects unknown cups-and-drinks children to the new parent" do
    get "/categories/cups-and-drinks/some-old-subcategory"
    assert_redirected_to "/categories/cups-and-accessories"
    assert_equal 301, response.status
  end

  test "redirects unknown hot-food children to food-containers" do
    get "/categories/hot-food/some-old-subcategory"
    assert_redirected_to "/categories/food-containers"
    assert_equal 301, response.status
  end

  # The one mapping slug history cannot express: the old hot-food/food-containers
  # child slug is now the live slug of its renamed parent, so it stays a static
  # route (config/routes.rb) and its target does not need to exist in fixtures.
  test "redirects renamed hot-food food-containers to food-containers-and-lids" do
    get "/categories/hot-food/food-containers"
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

  # Query strings survive every redirect layer, byte-for-byte (UTM tracking)
  test "preserves query parameters on renamed category redirect" do
    get "/categories/cups-and-drinks/hot-cups?utm_source=google&utm_campaign=test"
    assert_redirected_to "/categories/cups-and-accessories/hot-cups?utm_source=google&utm_campaign=test"
  end

  test "preserves query parameters on the renamed-parent fallback" do
    get "/categories/hot-food/some-old-subcategory?utm_source=google"
    assert_redirected_to "/categories/food-containers?utm_source=google"
  end

  test "preserves query parameters on the vegware filter redirect" do
    get "/collections/vegware/cups-and-drinks?utm_source=x&utm_medium=y"
    assert_redirected_to "/collections/vegware/cups-and-accessories?utm_source=x&utm_medium=y"
  end
end
