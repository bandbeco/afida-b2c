require "test_helper"
require "ostruct"

class SeoHelperTest < ActionView::TestCase
  # GBP helper tests
  test "gbp_rating_data returns hash with expected keys" do
    data = gbp_rating_data
    assert data.is_a?(Hash)
    assert data.key?(:rating)
    assert data.key?(:review_count)
    assert data.key?(:profile_url)
    assert data.key?(:place_id)
  end

  test "gbp_configured? returns false when rating is missing" do
    # Clear any memoized data
    @gbp_rating_data = { rating: nil, review_count: 5, profile_url: nil, place_id: nil }
    refute gbp_configured?
  end

  test "gbp_configured? returns false when review_count is missing" do
    @gbp_rating_data = { rating: 4.8, review_count: nil, profile_url: nil, place_id: nil }
    refute gbp_configured?
  end

  test "gbp_configured? returns true when rating and review_count present" do
    @gbp_rating_data = { rating: 4.8, review_count: 12, profile_url: "https://g.page/test", place_id: "ChIJtest" }
    assert gbp_configured?
  end

  test "gbp_profile_url returns profile_url when present" do
    @gbp_rating_data = { rating: 5.0, review_count: 2, profile_url: "https://g.page/custom", place_id: "ChIJtest" }
    assert_equal "https://g.page/custom", gbp_profile_url
  end

  test "gbp_profile_url falls back to search URL when profile_url missing" do
    @gbp_rating_data = { rating: 5.0, review_count: 2, profile_url: nil, place_id: "ChIJtest123" }
    assert_equal "https://search.google.com/local/reviews?placeid=ChIJtest123", gbp_profile_url
  end

  test "organization_structured_data includes aggregateRating when gbp configured" do
    @gbp_rating_data = { rating: 5.0, review_count: 2, profile_url: "https://g.page/test", place_id: "ChIJtest" }

    json = organization_structured_data
    data = JSON.parse(json)

    assert data["aggregateRating"].present?
    assert_equal "AggregateRating", data["aggregateRating"]["@type"]
    assert_equal "5.0", data["aggregateRating"]["ratingValue"]
    assert_equal "2", data["aggregateRating"]["reviewCount"]
    assert_equal "5", data["aggregateRating"]["bestRating"]
    assert_equal "1", data["aggregateRating"]["worstRating"]
  end

  test "organization_structured_data includes sameAs with social profiles" do
    @gbp_rating_data = { rating: 5.0, review_count: 2, profile_url: "https://g.page/test", place_id: "ChIJtest" }

    json = organization_structured_data
    data = JSON.parse(json)

    assert data["sameAs"].present?
    assert data["sameAs"].include?("https://www.linkedin.com/company/afidasupplies")
    assert data["sameAs"].include?("https://www.instagram.com/afidasupplies")
    assert data["sameAs"].include?("https://g.page/test")
  end

  test "organization_structured_data excludes aggregateRating when gbp not configured" do
    @gbp_rating_data = { rating: nil, review_count: nil, profile_url: nil, place_id: nil }

    json = organization_structured_data
    data = JSON.parse(json)

    refute data.key?("aggregateRating")
  end

  test "organization_structured_data includes description" do
    @gbp_rating_data = { rating: nil, review_count: nil, profile_url: nil, place_id: nil }

    json = organization_structured_data
    data = JSON.parse(json)

    assert_equal "Eco-friendly catering supplies for UK businesses", data["description"]
  end

  # Existing product structured data tests
  test "generates product JSON-LD structured data" do
    product = products(:single_wall_8oz_white)

    json = product_structured_data(product)
    data = JSON.parse(json)

    assert_equal "https://schema.org/", data["@context"]
    assert_equal "Product", data["@type"]
    # Uses generated_title (size + colour + name), not full_name (product_family + name)
    assert_equal product.generated_title, data["name"]
    assert_equal "Afida", data["brand"]["name"]
    assert_includes json, "offers"
  end

  test "generates organization JSON-LD structured data" do
    json = organization_structured_data
    data = JSON.parse(json)

    assert_equal "Organization", data["@type"]
    assert_equal "Afida", data["name"]
    assert_includes json, "contactPoint"
  end

  test "generates breadcrumb JSON-LD structured data" do
    items = [
      { name: "Home", url: root_url },
      { name: "Category", url: category_url("cups") }
    ]

    json = breadcrumb_structured_data(items)
    data = JSON.parse(json)

    assert_equal "BreadcrumbList", data["@type"]
    assert_equal 2, data["itemListElement"].length
  end

  # Product structured data tests (products are now first-class, not variants)
  test "generates product structured data with all required fields" do
    product = products(:single_wall_8oz_white)

    json = product_structured_data(product)
    data = JSON.parse(json)

    assert_equal "https://schema.org/", data["@context"]
    assert_equal "Product", data["@type"]
    # Uses generated_title (size + colour + name), not full_name (product_family + name)
    assert_equal product.generated_title, data["name"]
    assert_equal product.sku, data["sku"]
    assert_equal "Afida", data["brand"]["name"]
    assert data["offers"].present?
    assert_equal product.price.to_s, data["offers"]["price"]
    assert_equal "GBP", data["offers"]["priceCurrency"]
    assert_includes data["offers"]["url"], product.slug
  end

  test "product structured data includes gtin when present" do
    product = products(:single_wall_8oz_white)
    product.update!(gtin: "1234567890123")

    json = product_structured_data(product)
    data = JSON.parse(json)

    assert_equal "1234567890123", data["gtin"]
  end

  test "product structured data omits gtin when not present" do
    product = products(:single_wall_8oz_white)
    product.update!(gtin: nil)

    json = product_structured_data(product)
    data = JSON.parse(json)

    refute data.key?("gtin")
  end

  # Canonical URL tests
  test "canonical_url strips query parameters by default" do
    # Simulate a request with query params
    mock_request = OpenStruct.new(
      protocol: "https://",
      host_with_port: "afida.com",
      path: "/shop",
      original_url: "https://afida.com/shop?categories[]=cups&sort=price_asc"
    )

    # Stub the request method in the helper context
    self.define_singleton_method(:request) { mock_request }

    result = canonical_url
    assert_includes result, 'href="https://afida.com/shop"'
    refute_includes result, "categories"
    refute_includes result, "sort"
  end

  test "canonical_url uses provided URL when given" do
    mock_request = OpenStruct.new(
      protocol: "https://",
      host_with_port: "afida.com",
      path: "/shop",
      original_url: "https://afida.com/shop?q=test"
    )
    self.define_singleton_method(:request) { mock_request }

    result = canonical_url("https://afida.com/custom-path")
    assert_includes result, 'href="https://afida.com/custom-path"'
  end

  test "canonical_url generates proper link tag" do
    mock_request = OpenStruct.new(
      protocol: "https://",
      host_with_port: "afida.com",
      path: "/products/widget"
    )
    self.define_singleton_method(:request) { mock_request }

    result = canonical_url
    assert_includes result, 'rel="canonical"'
    assert_includes result, "<link"
  end
end
