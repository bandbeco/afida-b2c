require "test_helper"

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
    product = products(:single_wall_cups)
    variant = product.active_variants.first

    json = product_structured_data(product, variant)
    data = JSON.parse(json)

    assert_equal "https://schema.org/", data["@context"]
    assert_equal "Product", data["@type"]
    assert_equal product.name, data["name"]
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
end
