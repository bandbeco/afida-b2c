require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @product = products(:one)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) {
      count += 1 unless payload[:name] == "SCHEMA" || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET )/i
    }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  test "should destroy product_photo attachment" do
    # Attach a product photo
    file = fixture_file_upload("test_image.png", "image/png")
    @product.product_photo.attach(file)
    assert @product.product_photo.attached?, "Product photo should be attached before test"

    # Delete the product photo
    delete product_photo_admin_product_path(@product), headers: @headers

    @product.reload
    assert_not @product.product_photo.attached?, "Product photo should be purged after deletion"
  end

  test "should destroy lifestyle_photo attachment" do
    # Attach a lifestyle photo
    file = fixture_file_upload("test_image.png", "image/png")
    @product.lifestyle_photo.attach(file)
    assert @product.lifestyle_photo.attached?, "Lifestyle photo should be attached before test"

    # Delete the lifestyle photo
    delete lifestyle_photo_admin_product_path(@product), headers: @headers

    @product.reload
    assert_not @product.lifestyle_photo.attached?, "Lifestyle photo should be purged after deletion"
  end

  test "update permits description_short, description_standard, description_detailed parameters" do
    patch admin_product_path(@product), params: {
      product: {
        name: @product.name,
        description_short: "Updated short description",
        description_standard: "Updated standard description text",
        description_detailed: "Updated detailed description with full information"
      }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal "Updated short description", @product.description_short
    assert_equal "Updated standard description text", @product.description_standard
    assert_equal "Updated detailed description with full information", @product.description_detailed
  end

  test "edit form includes sample eligibility field" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[type=checkbox][name='product[sample_eligible]']"
  end

  test "edit form includes cost input field" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[name='product[cost]']"
  end

  test "update permits cost parameter" do
    patch admin_product_path(@product), params: {
      product: {
        name: @product.name,
        cost: "12.34"
      }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal 12.34, @product.cost
  end

  test "edit form includes all dimension input fields" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[name='product[length_in_mm]']"
    assert_select "input[name='product[width_in_mm]']"
    assert_select "input[name='product[height_in_mm]']"
    assert_select "input[name='product[depth_in_mm]']"
    assert_select "input[name='product[diameter_in_mm]']"
    assert_select "input[name='product[weight_in_g]']"
    assert_select "input[name='product[volume_in_ml]']"
  end

  test "edit form includes certifications input field" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[name='product[certifications]'], textarea[name='product[certifications]']"
  end

  test "update permits all dimension parameters" do
    patch admin_product_path(@product), params: {
      product: {
        length_in_mm: 254,
        width_in_mm: 90,
        height_in_mm: 120,
        depth_in_mm: 45,
        diameter_in_mm: 75,
        weight_in_g: 450,
        volume_in_ml: 250
      }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal 254, @product.length_in_mm
    assert_equal 90, @product.width_in_mm
    assert_equal 120, @product.height_in_mm
    assert_equal 45, @product.depth_in_mm
    assert_equal 75, @product.diameter_in_mm
    assert_equal 450, @product.weight_in_g
    assert_equal 250, @product.volume_in_ml
  end

  test "edit form includes supplier_sku input field" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[name='product[supplier_sku]']"
  end

  test "update permits supplier_sku parameter" do
    patch admin_product_path(@product), params: {
      product: { supplier_sku: "SUP-12345" }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal "SUP-12345", @product.supplier_sku
  end

  test "update permits certifications parameter" do
    patch admin_product_path(@product), params: {
      product: { certifications: "Compostable, Recyclable, FSC" }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal "Compostable, Recyclable, FSC", @product.certifications
  end

  test "should update sample eligibility" do
    assert_not @product.sample_eligible, "Product should not be sample eligible initially"

    patch admin_product_path(@product), params: {
      product: { sample_eligible: true }
    }, headers: @headers

    # Controller redirects to index after successful update
    assert_redirected_to admin_products_path
    @product.reload
    assert @product.sample_eligible, "Product should be sample eligible after update"
    assert_equal "SAMPLE-#{@product.sku}", @product.effective_sample_sku
  end

  # Inline category editing tests

  test "update_category updates product category" do
    new_category = categories(:child_hot_cups)

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: new_category.id }
    }, headers: @headers

    assert_response :success
    @product.reload
    assert_equal new_category.id, @product.category_id
  end

  test "update_category with invalid category returns unprocessable entity" do
    # Top-level categories are invalid (must be subcategory)
    top_level = categories(:parent_cups_and_drinks)

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: top_level.id }
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  # Inline family editing tests

  test "update_family reassigns product to a different family" do
    product = products(:single_wall_8oz_white)
    new_family = product_families(:branded_double_wall)

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: new_family.id }
    }, headers: @headers

    assert_response :success
    assert_equal new_family.id, product.reload.product_family_id
  end

  test "update_family with blank id un-assigns the family" do
    product = products(:single_wall_8oz_white)
    assert_not_nil product.product_family_id, "fixture should start with a family"

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: "" }
    }, headers: @headers

    assert_response :success
    assert_nil product.reload.product_family_id
  end

  test "update_family renders the family turbo frame" do
    product = products(:single_wall_8oz_white)

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: product_families(:paper_lids).id }
    }, headers: @headers

    assert_select "turbo-frame#product_#{product.id}_family"
    assert_select "select[name='product[product_family_id]']"
  end

  test "update_family requires admin" do
    sign_in_as(users(:consumer))
    product = products(:single_wall_8oz_white)
    original_family_id = product.product_family_id

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: product_families(:branded_double_wall).id }
    }, headers: @headers

    assert_redirected_to root_path
    assert_equal original_family_id, product.reload.product_family_id
  end

  test "update_category requires admin" do
    sign_in_as(users(:consumer))
    original_category_id = @product.category_id

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: categories(:child_hot_cups).id }
    }, headers: @headers

    assert_redirected_to root_path
    assert_equal original_category_id, @product.reload.category_id
  end

  test "index renders inline category and family auto-submit selects" do
    product = products(:single_wall_8oz_white)

    get admin_products_path, headers: @headers
    assert_response :success

    # Both selects present, scoped to the product's frames, wired to auto-submit
    assert_select "turbo-frame#product_#{product.id}_category form[data-controller='form']" do
      assert_select "select[name='product[category_id]'][data-action='change->form#submit']"
    end
    assert_select "turbo-frame#product_#{product.id}_family form[data-controller='form']" do
      assert_select "select[name='product[product_family_id]'][data-action='change->form#submit']"
    end

    # Category has NO blank option; Family HAS a blank "— None —" option
    assert_select "turbo-frame#product_#{product.id}_category select option[value='']", count: 0
    assert_select "turbo-frame#product_#{product.id}_family select option[value='']", text: "— None —"
  end

  test "index drops SKU, Pack Size, Featured, and Samples columns from the desktop table" do
    get admin_products_path, headers: @headers
    assert_response :success

    # Dropped to make room for the Category/Family selects and reduce clutter.
    assert_select "thead th", text: "SKU", count: 0
    assert_select "thead th", text: "Pack Size", count: 0
    assert_select "thead th", text: "Featured", count: 0
    assert_select "thead th", text: "Samples", count: 0

    # Active stays.
    assert_select "thead th", text: "Active", count: 1
  end

  test "index paginates to at most 50 products per page" do
    assert_operator Product.unscoped.count, :>, 50, "fixtures should exceed one page"

    get admin_products_path, headers: @headers
    assert_response :success

    # Desktop table renders one <tr> per product in <tbody>; cap is Pagy's limit.
    assert_select "tbody tr", maximum: 50
    # A pagination nav is rendered when there is more than one page.
    assert_select "nav.pagy"
  end

  test "index renders without a per-row query explosion" do
    get admin_products_path, headers: @headers # warm caches/eager-load

    # The category-options and family-options lists are page-invariant, so the
    # whole index must stay flat in query count, not scale with the row count.
    count = count_queries do
      get admin_products_path, headers: @headers
    end
    assert_operator count, :<, 40,
      "index issued #{count} SQL queries; expected a flat, row-count-independent total"
  end

  # Inline boolean toggle tests

  test "toggle_boolean enables active on product" do
    @product.update!(active: false)

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "active", value: "1"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert @product.active
  end

  test "toggle_boolean disables featured on product" do
    @product.update!(featured: true)

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "featured", value: "0"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert_not @product.featured
  end

  test "toggle_boolean enables sample_eligible on product" do
    assert_not @product.sample_eligible

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "sample_eligible", value: "1"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert @product.sample_eligible
  end

  test "toggle_boolean rejects non-allowed fields" do
    patch toggle_boolean_admin_product_path(@product), params: {
      field: "name", value: "hacked"
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  # Title preview tests — the preview must be server-rendered from
  # Product#generated_title so it can never drift from the persisted title.

  test "preview_title renders the generated title from submitted form values" do
    post preview_title_admin_products_path, params: {
      product: { brand: "Vegware", colour: "White", material: "Paper", name: "Coffee Cups", size: "12oz" }
    }, headers: @headers.merge("Accept" => "text/vnd.turbo-stream.html")

    assert_response :success
    assert_select "turbo-stream[action=update][target=title-preview]" do
      assert_select "template", text: /Vegware White Paper Coffee Cups - 12oz/
    end
  end

  test "preview_title derives the size token from dimensions when size is blank" do
    post preview_title_admin_products_path, params: {
      product: { name: "Flexy Pint Glasses to Brim", length_in_mm: 200, width_in_mm: 300 }
    }, headers: @headers.merge("Accept" => "text/vnd.turbo-stream.html")

    assert_response :success
    assert_select "turbo-stream[action=update][target=title-preview] template",
                  text: /Flexy Pint Glasses to Brim - 200 x 300mm/
  end

  test "preview_title falls back to placeholder when no details are present" do
    post preview_title_admin_products_path, params: {
      product: { name: "" }
    }, headers: @headers.merge("Accept" => "text/vnd.turbo-stream.html")

    assert_response :success
    assert_select "turbo-stream[action=update][target=title-preview] template",
                  text: /Enter product details above/
  end

  test "preview_title requires admin" do
    sign_in_as(users(:consumer))

    post preview_title_admin_products_path, params: {
      product: { name: "Sneaky" }
    }, headers: @headers.merge("Accept" => "text/vnd.turbo-stream.html")

    assert_redirected_to root_path
  end

  # Regression: a failed create re-renders the form with the uploaded photo still
  # held in memory on the unsaved Product. The form preview must not try to build a
  # URL for the in-memory blob (ActiveStorage raises "Cannot get a signed_id for a
  # new record" on an unpersisted blob), which previously turned the validation
  # error into a 500.
  test "create with photo but invalid data re-renders form without raising" do
    subcategory = categories(:child_cold_cups)

    assert_no_difference -> { Product.unscoped.count } do
      post admin_products_path, params: {
        product: {
          name: "Invalid Product With Photo",
          # sku is required and left blank, so the save fails and :new is re-rendered
          sku: "",
          price: "9.99",
          category_id: subcategory.id,
          product_photo: fixture_file_upload("test_image.png", "image/png")
        }
      }, headers: @headers
    end

    assert_response :unprocessable_entity
    assert_select "form"
  end
end
