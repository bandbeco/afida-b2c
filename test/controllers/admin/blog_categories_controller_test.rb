require "test_helper"

class Admin::BlogCategoriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @blog_category = blog_categories(:guides)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "edit form posts to the persisted slug after a malformed slug is rejected" do
    patch admin_blog_category_path(@blog_category), headers: @headers, params: {
      blog_category: { slug: "Not A Slug!" }
    }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", admin_blog_category_path(@blog_category.reload)
  end

  test "edit form does not post to another record after a duplicate slug is rejected" do
    other = blog_categories(:news)

    patch admin_blog_category_path(@blog_category), headers: @headers, params: {
      blog_category: { slug: other.slug }
    }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", admin_blog_category_path(@blog_category.reload)
  end
end
