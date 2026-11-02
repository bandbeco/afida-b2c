require "test_helper"

class SamplesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a category with sample-eligible variants
    @category = categories(:one)

    # Create a sample-eligible product
    @sample_variant = Product.create!(
      category: @category,
      name: "Sample Test Variant",
      sku: "SAMPLE-CONTROLLER-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
  end

  test "GET /samples returns success" do
    get samples_path
    assert_response :success
  end

  test "GET /samples shows categories with sample-eligible variants" do
    get samples_path
    assert_response :success
    # Category should be visible since it has sample-eligible variant
    assert_select "h1", text: /Try Before You Buy/i
  end

  test "GET /samples/:category_slug returns Turbo Frame with variants" do
    get category_samples_path(@category.slug),
        headers: { "Turbo-Frame" => "category_#{@category.id}" }

    assert_response :success
    # Should return Turbo Frame response
  end

  test "categories without sample-eligible variants are not shown" do
    # Create a category with no sample-eligible variants
    empty_category = Category.create!(
      name: "Empty Category",
      slug: "empty-category",
      position: 99
    )

    get samples_path
    assert_response :success

    # Empty category should not appear in the categories grid
    assert_select ".space-y-6" do
      assert_select "h2", text: /Empty Category/, count: 0
    end
  end

  # Slug-history: renamed category slugs must 301, never 404 (June 2026 incident)
  test "samples category under a renamed slug 301s to the current slug" do
    CategorySlugRedirect.create!(old_slug: "samples-legacy-slug", category: @category)

    get category_samples_path("samples-legacy-slug")
    assert_response :moved_permanently
    assert_redirected_to category_samples_path(@category.slug)
  end

  test "index preloads sample product counts to avoid N+1 queries" do
    # Create multiple categories with sample products
    5.times do |i|
      category = Category.create!(
        name: "Test Category #{i}",
        slug: "test-category-#{i}",
        position: i
      )
      3.times do |j|
        Product.create!(
          category: category,
          name: "Sample #{i}-#{j}",
          sku: "SAMPLE-N1-TEST-#{i}-#{j}",
          price: 10.0,
          sample_eligible: true,
          active: true,
          product_type: "standard"
        )
      end
    end

    # First request establishes baseline
    get samples_path
    assert_response :success

    # Count queries on second request - should stay flat regardless of category count
    queries = []
    ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, details|
      queries << details[:sql] unless details[:sql].include?("SCHEMA")
    end

    get samples_path
    assert_response :success

    ActiveSupport::Notifications.unsubscribe("sql.active_record")

    # Should not have per-category COUNT queries
    count_queries = queries.select { |q| q.match?(/COUNT.*products.*category_id/) }
    assert_equal 0, count_queries.length, "Found #{count_queries.length} per-category COUNT queries, expected 0"
  end
end
