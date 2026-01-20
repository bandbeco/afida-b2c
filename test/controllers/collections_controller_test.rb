require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @collection = collections(:coffee_shop_essentials)
    @empty_collection = collections(:empty_collection)
    @sample_pack = collections(:coffee_shop_sample_pack)
  end

  # ==========================================================================
  # GET /collections (index)
  # ==========================================================================

  test "index shows featured collections" do
    get collections_url
    assert_response :success
    assert_match @collection.name, response.body
  end

  test "index excludes sample pack collections" do
    get collections_url
    assert_response :success
    assert_no_match @sample_pack.name, response.body
  end

  test "index is publicly accessible" do
    get collections_url
    assert_response :success
  end

  test "index is accessible to authenticated users" do
    sign_in_as(users(:one))
    get collections_url
    assert_response :success
  end

  # ==========================================================================
  # GET /collections/:slug (show)
  # ==========================================================================

  test "show displays collection by slug" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_match @collection.name, response.body
  end

  test "show displays collection products" do
    get collection_url(@collection.slug)
    assert_response :success
    # Collection has products from fixtures
    @collection.products.active.each do |product|
      assert_match product.generated_title, response.body
    end
  end

  test "show displays collection description" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_match @collection.description, response.body
  end

  test "show renders empty state for empty collection" do
    get collection_url(@empty_collection.slug)
    assert_response :success
    # Should show empty state message
    assert_match(/no products/i, response.body)
  end

  test "show is publicly accessible" do
    get collection_url(@collection.slug)
    assert_response :success
  end

  test "show is accessible to authenticated users" do
    sign_in_as(users(:one))
    get collection_url(@collection.slug)
    assert_response :success
  end

  test "show returns 404 for non-existent slug" do
    get "/collections/non-existent-collection"
    assert_response :not_found
  end

  # ==========================================================================
  # SEO Tests
  # ==========================================================================

  test "show includes meta title" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "title", text: /#{@collection.meta_title}/
  end

  test "show includes meta description" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "meta[name=description]" do |elements|
      assert elements.any? { |e| e[:content].include?(@collection.meta_description) }
    end
  end

  test "show includes structured data" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "script[type='application/ld+json']"
  end

  test "show includes breadcrumbs" do
    get collection_url(@collection.slug)
    assert_response :success
    # Breadcrumb should include home and collection name
    assert_match "Home", response.body
    assert_match @collection.name, response.body
  end

  # ==========================================================================
  # URL Tests
  # ==========================================================================

  test "collection URLs use SEO-friendly slugs" do
    get collection_url(@collection.slug)
    assert_response :success
    # URL should contain the slug, not numeric ID
    assert_includes request.path, @collection.slug
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
