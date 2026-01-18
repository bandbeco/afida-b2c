require "test_helper"

class Admin::CollectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @collection = collections(:coffee_shop_essentials)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  # ==========================================================================
  # GET /admin/collections (index)
  # ==========================================================================

  test "should get index" do
    get admin_collections_path, headers: @headers
    assert_response :success
    assert_match /Collections/, response.body
    assert_match @collection.name, response.body
  end

  test "index shows all collections including sample packs" do
    get admin_collections_path, headers: @headers
    assert_response :success

    # Should show regular collections
    assert_match collections(:coffee_shop_essentials).name, response.body
    # Should also show sample packs
    assert_match collections(:coffee_shop_sample_pack).name, response.body
  end

  # ==========================================================================
  # GET /admin/collections/new (new)
  # ==========================================================================

  test "should get new" do
    get new_admin_collection_path, headers: @headers
    assert_response :success
    assert_match /New Collection/, response.body
  end

  # ==========================================================================
  # POST /admin/collections (create)
  # ==========================================================================

  test "should create collection" do
    assert_difference("Collection.count") do
      post admin_collections_path, headers: @headers, params: {
        collection: {
          name: "Restaurant Favorites",
          slug: "restaurant-favorites",
          description: "Best products for restaurants",
          meta_title: "Restaurant Products | Afida",
          meta_description: "Top eco-friendly supplies for restaurants",
          featured: true,
          sample_pack: false
        }
      }
    end

    assert_redirected_to admin_collections_path
    follow_redirect!
    assert_match /Collection was successfully created/, response.body

    # Verify the collection was created with correct attributes
    collection = Collection.find_by(slug: "restaurant-favorites")
    assert_not_nil collection
    assert_equal "Restaurant Favorites", collection.name
    assert collection.featured
    assert_not collection.sample_pack
  end

  test "should create sample pack collection" do
    assert_difference("Collection.count") do
      post admin_collections_path, headers: @headers, params: {
        collection: {
          name: "Restaurant Sample Pack",
          slug: "restaurant-sample-pack",
          description: "Sample products for restaurants",
          featured: false,
          sample_pack: true
        }
      }
    end

    collection = Collection.find_by(slug: "restaurant-sample-pack")
    assert collection.sample_pack
    assert_not collection.featured
  end

  test "create with invalid data re-renders form" do
    assert_no_difference("Collection.count") do
      post admin_collections_path, headers: @headers, params: {
        collection: { name: "", slug: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ==========================================================================
  # GET /admin/collections/:id/edit (edit)
  # ==========================================================================

  test "should get edit" do
    get edit_admin_collection_path(@collection.id), headers: @headers
    assert_response :success
    assert_match /Edit Collection/, response.body
    assert_match @collection.name, response.body
  end

  # ==========================================================================
  # PATCH /admin/collections/:id (update)
  # ==========================================================================

  test "should update collection" do
    patch admin_collection_path(@collection.id), headers: @headers, params: {
      collection: {
        name: "Updated Collection Name",
        description: "Updated description"
      }
    }

    assert_redirected_to admin_collections_path
    follow_redirect!
    assert_match /Collection was successfully updated/, response.body

    @collection.reload
    assert_equal "Updated Collection Name", @collection.name
    assert_equal "Updated description", @collection.description
  end

  test "update with invalid data re-renders form" do
    patch admin_collection_path(@collection.id), headers: @headers, params: {
      collection: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # ==========================================================================
  # DELETE /admin/collections/:id (destroy)
  # ==========================================================================

  test "should destroy collection" do
    collection_to_delete = collections(:empty_collection)

    assert_difference("Collection.count", -1) do
      delete admin_collection_path(collection_to_delete.id), headers: @headers
    end

    assert_redirected_to admin_collections_path
    follow_redirect!
    assert_match /Collection was successfully deleted/, response.body
  end

  # ==========================================================================
  # GET /admin/collections/order (order)
  # ==========================================================================

  test "should get order page" do
    get order_admin_collections_path, headers: @headers
    assert_response :success
    assert_match /Order Collections/, response.body
  end

  # ==========================================================================
  # PATCH /admin/collections/:id/move_higher
  # ==========================================================================

  test "should move collection higher" do
    # Get a collection that can move higher
    collection = Collection.regular.by_position.last
    original_position = collection.position

    patch move_higher_admin_collection_path(collection.id), headers: @headers

    collection.reload
    assert_operator collection.position, :<, original_position
  end

  # ==========================================================================
  # PATCH /admin/collections/:id/move_lower
  # ==========================================================================

  test "should move collection lower" do
    collection = Collection.regular.by_position.first
    original_position = collection.position

    patch move_lower_admin_collection_path(collection.id), headers: @headers

    collection.reload
    assert_operator collection.position, :>, original_position
  end

  # ==========================================================================
  # Product assignment
  # ==========================================================================

  test "should update collection with product ids" do
    product1 = products(:one)
    product2 = products(:two)

    # Start with empty collection
    empty_collection = collections(:empty_collection)
    assert_equal 0, empty_collection.products.count

    patch admin_collection_path(empty_collection.id), headers: @headers, params: {
      collection: {
        name: empty_collection.name,
        product_ids: [ product1.id, product2.id ]
      }
    }

    assert_redirected_to admin_collections_path

    empty_collection.reload
    assert_equal 2, empty_collection.products.count
    assert_includes empty_collection.products, product1
    assert_includes empty_collection.products, product2
  end
end
