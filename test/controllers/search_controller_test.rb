require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant = products(:single_wall_8oz_white)
  end

  test "index returns success" do
    get search_url, params: { q: "8oz" }
    assert_response :success
  end

  test "index returns empty results for short query" do
    get search_url, params: { q: "a" }
    assert_response :success
    assert_select ".product-card", count: 0
  end

  test "index returns empty results for blank query" do
    get search_url, params: { q: "" }
    assert_response :success
    assert_select ".product-card", count: 0
  end

  test "index limits results to 5" do
    # Create enough variants to test limit
    # Using existing fixtures - just verify limit is applied
    get search_url, params: { q: "cup" }
    assert_response :success

    # Count should be <= 5
    assert_select ".product-card", maximum: 5
  end

  test "index finds variants by name" do
    get search_url, params: { q: "8oz" }
    assert_response :success
    assert_select "a[href=?]", product_path(@variant.slug)
  end

  test "index finds variants by sku" do
    get search_url, params: { q: @variant.sku }
    assert_response :success
    assert_select "a[href=?]", product_path(@variant.slug)
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

  # Modal mode tests
  test "modal mode returns up to 10 results" do
    get search_url, params: { q: "cup", modal: "true" }
    assert_response :success
    # Modal mode should return more results (up to 10)
    assert_select "a[href*='/products/']", maximum: 10
  end

  test "modal mode returns modal_results partial" do
    get search_url, params: { q: "8oz", modal: "true" }
    assert_response :success
    # Modal results use space-y-2 list layout for stacked rows
    assert_select ".space-y-2"
  end

  test "modal turbo stream updates correct frame" do
    get search_url, params: { q: "8oz", modal: "true" }, as: :turbo_stream
    assert_response :success
    assert_match(/search-modal-results/, response.body)
  end

  test "non-modal turbo stream updates header frame" do
    get search_url, params: { q: "8oz" }, as: :turbo_stream
    assert_response :success
    assert_match(/header-search-results/, response.body)
  end
end
