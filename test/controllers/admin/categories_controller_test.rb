require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @category = categories(:cups)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "should get index" do
    get admin_categories_path, headers: @headers
    assert_response :success
    assert_match /Categories/, response.body
    assert_match @category.name, response.body
  end

  test "should get new" do
    get new_admin_category_path, headers: @headers
    assert_response :success
    assert_match /New Category/, response.body
  end

  test "should create category" do
    assert_difference("Category.count") do
      post admin_categories_path, headers: @headers, params: {
        category: {
          name: "Test Category",
          slug: "test-category",
          description: "A test category",
          meta_title: "Test Category | Afida",
          meta_description: "Test category description",
          position: 100
        }
      }
    end

    assert_redirected_to admin_categories_path
    follow_redirect!
    assert_match /Category was successfully created/, response.body

    # Verify the category was created with correct attributes
    category = Category.find_by(slug: "test-category")
    assert_not_nil category
    assert_equal "Test Category", category.name
    assert_equal "A test category", category.description
  end

  test "should update category with FAQs" do
    faqs = [
      { "question" => "What is this?", "answer" => "A test category." },
      { "question" => "Is it good?", "answer" => "Yes, very good." }
    ]

    patch admin_category_path(@category), headers: @headers, params: {
      category: {
        faqs: faqs.to_json
      }
    }

    assert_redirected_to admin_categories_path
    @category.reload
    assert_equal 2, @category.faqs.size
    assert_equal "What is this?", @category.faqs.first["question"]
  end

  test "edit form shows FAQs section" do
    get edit_admin_category_path(@category), headers: @headers
    assert_response :success
    assert_select "h2", text: /FAQs/
  end

  test "should get edit" do
    get edit_admin_category_path(@category), headers: @headers
    assert_response :success
    assert_match /Edit Category/, response.body
    assert_match @category.name, response.body
  end

  test "should update category" do
    patch admin_category_path(@category), headers: @headers, params: {
      category: {
        name: "Updated Name",
        description: "Updated description"
      }
    }

    assert_redirected_to admin_categories_path
    follow_redirect!
    assert_match /Category was successfully updated/, response.body

    @category.reload
    assert_equal "Updated Name", @category.name
    assert_equal "Updated description", @category.description
  end

  test "should update category with image" do
    file = fixture_file_upload("test_image.png", "image/png")

    patch admin_category_path(@category), headers: @headers, params: {
      category: {
        name: @category.name,
        image: file
      }
    }

    assert_redirected_to admin_categories_path

    @category.reload
    assert @category.image.attached?, "Image should be attached"
  end

  test "should destroy category" do
    # Create a category without products for deletion test
    category_to_delete = Category.create!(
      name: "Deletable Category",
      slug: "deletable-category",
      position: 100
    )

    assert_difference("Category.count", -1) do
      delete admin_category_path(category_to_delete), headers: @headers
    end

    assert_redirected_to admin_categories_path
    follow_redirect!
    assert_match /Category was successfully deleted/, response.body
  end

  test "should not create category with invalid data" do
    assert_no_difference("Category.count") do
      post admin_categories_path, headers: @headers, params: {
        category: {
          name: "",
          slug: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not update category with invalid data" do
    original_name = @category.name

    patch admin_category_path(@category), headers: @headers, params: {
      category: {
        name: ""
        # Don't set slug to empty as it causes routing issues
      }
    }

    assert_response :unprocessable_entity

    @category.reload
    assert_equal original_name, @category.name
  end

  test "should create subcategory with parent" do
    parent = categories(:parent_cups_and_drinks)

    assert_difference("Category.count") do
      post admin_categories_path, headers: @headers, params: {
        category: {
          name: "New Sub",
          slug: "new-sub",
          parent_id: parent.id
        }
      }
    end

    assert_redirected_to admin_categories_path
    category = Category.find_by(slug: "new-sub")
    assert_equal parent.id, category.parent_id
  end

  test "should reassign parent category" do
    child = categories(:child_hot_cups)
    new_parent = categories(:parent_hot_food)

    patch admin_category_path(child), headers: @headers, params: {
      category: { parent_id: new_parent.id }
    }

    assert_redirected_to admin_categories_path
    child.reload
    assert_equal new_parent.id, child.parent_id
  end

  test "should promote subcategory to top-level by removing parent" do
    child = categories(:child_hot_cups)
    assert_not_nil child.parent_id

    patch admin_category_path(child), headers: @headers, params: {
      category: { parent_id: "" }
    }

    assert_redirected_to admin_categories_path
    child.reload
    assert_nil child.parent_id
  end

  test "new category form shows parent category dropdown" do
    get new_admin_category_path, headers: @headers
    assert_response :success
    assert_select "select[name='category[parent_id]']"
  end

  test "edit category form shows parent category dropdown" do
    get edit_admin_category_path(@category), headers: @headers
    assert_response :success
    assert_select "select[name='category[parent_id]']"
  end

  test "parent dropdown excludes the category being edited" do
    parent = categories(:parent_cups_and_drinks)
    get edit_admin_category_path(parent), headers: @headers
    assert_response :success
    assert_select "select[name='category[parent_id]'] option[value='#{parent.id}']", count: 0
  end

  test "parent dropdown only shows top-level categories" do
    child = categories(:child_hot_cups)
    get new_admin_category_path, headers: @headers
    assert_response :success
    assert_select "select[name='category[parent_id]'] option[value='#{child.id}']", count: 0
  end

  test "index shows categories grouped by parent with children" do
    get admin_categories_path, headers: @headers
    assert_response :success
    assert_select "td", text: /Cups & Drinks/
    assert_select "td", text: /Hot Cups/
  end

  test "should use slug in URLs not numeric ID" do
    # Create a category without products for deletion test
    test_category = Category.create!(
      name: "URL Test Category",
      slug: "url-test-category",
      position: 101
    )

    # Edit URL should use slug
    get edit_admin_category_path(test_category.slug), headers: @headers
    assert_response :success

    # Update should work with slug
    patch admin_category_path(test_category.slug), headers: @headers, params: {
      category: { name: "New Name" }
    }
    assert_redirected_to admin_categories_path

    # Delete should work with slug
    delete admin_category_path(test_category.slug), headers: @headers
    assert_redirected_to admin_categories_path
  end
end
