require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant = product_variants(:single_wall_8oz_white)
  end

  test "index returns success" do
    get search_url, params: { q: "8oz" }
    assert_response :success
  end

  test "index returns empty results for short query" do
    get search_url, params: { q: "a" }
    assert_response :success
    assert_select ".variant-card", count: 0
  end

  test "index returns empty results for blank query" do
    get search_url, params: { q: "" }
    assert_response :success
    assert_select ".variant-card", count: 0
  end

  test "index limits results to 5" do
    # Create enough variants to test limit
    # Using existing fixtures - just verify limit is applied
    get search_url, params: { q: "cup" }
    assert_response :success

    # Count should be <= 5
    assert_select ".variant-card", maximum: 5
  end

  test "index finds variants by name" do
    get search_url, params: { q: "8oz" }
    assert_response :success
    assert_select "a[href=?]", product_variant_path(@variant.slug)
  end

  test "index finds variants by sku" do
    get search_url, params: { q: @variant.sku }
    assert_response :success
    assert_select "a[href=?]", product_variant_path(@variant.slug)
  end

  test "index is accessible without authentication" do
    get search_url, params: { q: "test" }
    assert_response :success
  end

  test "index returns turbo stream format when requested" do
    get search_url, params: { q: "8oz" }, as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream/, response.media_type)
  end

  test "index shows view all link when results exist" do
    get search_url, params: { q: "8oz" }
    assert_response :success
    # Should link to shop with search query
    assert_select "a[href=?]", shop_path(q: "8oz")
  end

  test "index handles query with special characters" do
    get search_url, params: { q: "test%20query" }
    assert_response :success
  end

  test "index handles very long query" do
    long_query = "a" * 200
    get search_url, params: { q: long_query }
    assert_response :success
  end
end
