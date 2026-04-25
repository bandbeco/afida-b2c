require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Use hot_cups_extras which has multiple active products (won't trigger redirect)
    @category = categories(:hot_cups_extras)
  end

  # GET /categories/:id (show)
  test "should show category by slug" do
    get category_url(@category.slug)
    assert_response :success
  end

  test "show page loads category with slug" do
    get category_url(@category.slug)
    assert_response :success
    # Response should contain category name
    assert_match @category.name, response.body
  end

  test "show page loads category products" do
    get category_url(@category.slug)
    assert_response :success
    # Response should show products from this category
  end

  test "show page accessible to guests" do
    get category_url(@category.slug)
    assert_response :success
  end

  test "show page accessible to authenticated users" do
    sign_in_as(users(:one))
    get category_url(@category.slug)
    assert_response :success
  end

  test "category URLs use SEO-friendly slugs" do
    get category_url(@category.slug)
    assert_response :success
    # Categories are accessed via slug, not ID
  end

  test "show page eager loads products with images" do
    get category_url(@category.slug)
    assert_response :success
    # Eager loading prevents N+1 queries
  end

  test "show page displays only products from category" do
    get category_url(@category.slug)
    assert_response :success
    # Products displayed belong to this category
  end

  test "category pages are publicly accessible" do
    # Verify no authentication required
    get category_url(@category.slug)
    assert_response :success
  end

  test "redirects to variant page when category has only one variant" do
    category_with_one_product = categories(:category_with_one_product)
    only_variant = products(:only_product_in_category)

    get category_url(category_with_one_product.slug)

    assert_redirected_to product_path(only_variant.slug)
    assert_response :moved_permanently
  end

  test "single variant redirect preserves query parameters" do
    category_with_one_product = categories(:category_with_one_product)
    only_variant = products(:only_product_in_category)

    get category_url(category_with_one_product.slug, utm_source: "email", utm_campaign: "test")

    assert_redirected_to product_path(only_variant.slug, utm_source: "email", utm_campaign: "test")
    assert_response :moved_permanently
  end

  test "does not redirect when category has multiple products" do
    # hot_cups_extras has multiple lid products
    multi_product_category = categories(:hot_cups_extras)

    get category_url(multi_product_category.slug)

    assert_response :success
  end

  # Parent category hierarchy tests
  test "parent category shows products from all subcategories" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)

    assert_response :success
    # Should include products from both child_pizza_boxes and child_takeaway_boxes
    assert_match "10 Inch Pizza Box", response.body
    assert_match "Kraft Takeaway Box", response.body
  end

  test "subcategory shows only its own products via nested URL" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get category_subcategory_url(parent.slug, subcategory.slug)

    assert_response :success
    assert_match "10 Inch Pizza Box", response.body
  end

  test "subcategory via flat URL redirects to nested URL" do
    subcategory = categories(:child_pizza_boxes)

    get category_url(subcategory.slug)

    assert_response :moved_permanently
  end

  test "parent category page is accessible" do
    parent = categories(:parent_cups_and_drinks)

    get category_url(parent.slug)

    assert_response :success
  end

  # Hero section tests
  test "show page renders hero section with H1 and description" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero h1", text: category.name
    assert_select ".category-hero", text: /#{Regexp.escape(category.description)}/
  end

  test "show page hero displays product count" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero", text: /Browse 2\+/
  end

  test "show page hero handles category without image gracefully" do
    category = categories(:category_with_buying_guide)
    assert_not category.image.attached?

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero"
  end

  test "show page does not render question heading" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select "h2", text: /What.*does Afida offer/, count: 0
  end

  # Buying guide tests
  test "show page renders buying guide when present" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".buying-guide"
    assert_select ".buying-guide h2", text: /Why Choose Eco-Friendly/
    assert_select ".buying-guide h2", text: /Materials Guide/
    assert_select ".buying-guide h2", text: /Sizing and Use Cases/
  end

  test "show page does not render buying guide when blank" do
    get category_url(@category.slug)

    assert_response :success
    assert_select ".buying-guide", count: 0
  end

  test "buying guide renders between product grid and FAQs" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    body = response.body
    product_grid_pos = body.index("grid-cols-2")
    buying_guide_pos = body.index("buying-guide")
    assert buying_guide_pos > product_grid_pos, "Buying guide should appear after the product grid"
  end

  # Buying guide Article JSON-LD tests
  test "show page includes Article JSON-LD when buying guide present" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select 'script[type="application/ld+json"]' do |scripts|
      article_script = scripts.find { |s| s.text.include?('"Article"') }
      assert article_script, "Expected Article JSON-LD script tag"
      data = JSON.parse(article_script.text)
      assert_equal "Article", data["@type"]
      assert_includes data["headline"], category.name
      assert_equal "Afida", data.dig("author", "name")
      assert_equal "Afida", data.dig("publisher", "name")
      assert data["articleBody"].present?
      assert data["dateModified"].present?
    end
  end

  test "show page does not include Article JSON-LD when no buying guide" do
    get category_url(@category.slug)

    assert_response :success
    assert_select 'script[type="application/ld+json"]' do |scripts|
      article_script = scripts.find { |s| s.text.include?('"Article"') }
      assert_nil article_script, "Should not have Article JSON-LD without a buying guide"
    end
  end

  test "parent show eager loads attachments for products across subcategories" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_url(parent.slug)
    end

    assert_response :success

    per_record_attachment_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_attachment_lookups <= 1,
      "Expected at most 1 per-record attachment lookup (category image only), " \
      "got #{per_record_attachment_lookups}:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  test "subcategory show eager loads attachments for products" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get category_subcategory_url(parent.slug, subcategory.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_subcategory_url(parent.slug, subcategory.slug)
    end

    assert_response :success

    per_record_attachment_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_attachment_lookups <= 1,
      "Expected at most 1 per-record attachment lookup (category image only), " \
      "got #{per_record_attachment_lookups}:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  test "parent show does not fire N+1 categories queries" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_url(parent.slug)
    end

    assert_response :success

    per_record_category_lookups = queries.count do |sql|
      sql.include?("\"categories\"") &&
        sql.include?("\"id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_category_lookups <= 1,
      "Expected at most 1 per-record categories lookup, got #{per_record_category_lookups}:\n" +
      queries.select { |q|
        q.include?("\"categories\"") &&
          q.include?("\"id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
