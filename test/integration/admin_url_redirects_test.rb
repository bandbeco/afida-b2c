# frozen_string_literal: true

require "test_helper"

class AdminUrlRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
    @admin = users(:acme_admin)
    @product = Product.first

    # Sign in as admin
    post session_url, params: { email_address: @admin.email_address, password: "password" }, headers: @headers
  end

  # T077: Admin CRUD workflow
  test "should complete full CRUD workflow for legacy redirects" do
    # Create a new redirect
    get new_admin_url_redirect_path
    assert_response :success

    assert_difference("UrlRedirect.count") do
      post admin_url_redirects_path, params: {
        url_redirect: {
          source_path: "/product/integration-crud-test",
          target_slug: @product.slug,
          variant_params: '{"size": "12\""}',
          active: true
        }
      }
    end

    redirect = UrlRedirect.last
    assert_redirected_to admin_url_redirect_path(redirect)

    # View the redirect
    follow_redirect!
    assert_response :success
    assert_select "td", text: "/product/integration-crud-test"

    # Edit the redirect
    get edit_admin_url_redirect_path(redirect)
    assert_response :success

    patch admin_url_redirect_path(redirect), params: {
      url_redirect: {
        active: false
      }
    }

    assert_redirected_to admin_url_redirect_path(redirect)
    assert_equal false, redirect.reload.active

    # Delete the redirect
    assert_difference("UrlRedirect.count", -1) do
      delete admin_url_redirect_path(redirect)
    end

    assert_redirected_to admin_url_redirects_path
  end

  # T078: Bulk operations (toggle multiple redirects)
  test "should toggle multiple redirects" do
    redirect1 = UrlRedirect.create!(
      source_path: "/product/bulk-1",
      target_slug: @product.slug,
      active: true
    )
    redirect2 = UrlRedirect.create!(
      source_path: "/product/bulk-2",
      target_slug: @product.slug,
      active: true
    )

    # Toggle first redirect
    patch toggle_admin_url_redirect_path(redirect1)
    assert_equal false, redirect1.reload.active

    # Toggle second redirect
    patch toggle_admin_url_redirect_path(redirect2)
    assert_equal false, redirect2.reload.active

    # Toggle back
    patch toggle_admin_url_redirect_path(redirect1)
    assert_equal true, redirect1.reload.active
  end
end
