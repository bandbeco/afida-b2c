# frozen_string_literal: true

require "test_helper"

class AdminLegacyRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
    @admin = User.first || User.create!(email_address: "admin@test.com", password: "password")
    @product = Product.first

    # Sign in as admin
    post session_url, params: { email_address: @admin.email_address, password: "password" }, headers: @headers
  end

  # T077: Admin CRUD workflow
  test "should complete full CRUD workflow for legacy redirects" do
    # Create a new redirect
    get new_admin_legacy_redirect_path
    assert_response :success

    assert_difference("LegacyRedirect.count") do
      post admin_legacy_redirects_path, params: {
        legacy_redirect: {
          legacy_path: "/product/integration-crud-test",
          target_slug: @product.slug,
          variant_params: '{"size": "12\""}',
          active: true
        }
      }
    end

    redirect = LegacyRedirect.last
    assert_redirected_to admin_legacy_redirect_path(redirect)

    # View the redirect
    follow_redirect!
    assert_response :success
    assert_select "td", text: "/product/integration-crud-test"

    # Edit the redirect
    get edit_admin_legacy_redirect_path(redirect)
    assert_response :success

    patch admin_legacy_redirect_path(redirect), params: {
      legacy_redirect: {
        active: false
      }
    }

    assert_redirected_to admin_legacy_redirect_path(redirect)
    assert_equal false, redirect.reload.active

    # Delete the redirect
    assert_difference("LegacyRedirect.count", -1) do
      delete admin_legacy_redirect_path(redirect)
    end

    assert_redirected_to admin_legacy_redirects_path
  end

  # T078: Bulk operations (toggle multiple redirects)
  test "should toggle multiple redirects" do
    redirect1 = LegacyRedirect.create!(
      legacy_path: "/product/bulk-1",
      target_slug: @product.slug,
      active: true
    )
    redirect2 = LegacyRedirect.create!(
      legacy_path: "/product/bulk-2",
      target_slug: @product.slug,
      active: true
    )

    # Toggle first redirect
    patch toggle_admin_legacy_redirect_path(redirect1)
    assert_equal false, redirect1.reload.active

    # Toggle second redirect
    patch toggle_admin_legacy_redirect_path(redirect2)
    assert_equal false, redirect2.reload.active

    # Toggle back
    patch toggle_admin_legacy_redirect_path(redirect1)
    assert_equal true, redirect1.reload.active
  end
end
