# frozen_string_literal: true

require "test_helper"

class Admin::LegacyRedirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Set modern browser user agent
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }

    @product = Product.first
    @redirect = LegacyRedirect.create!(
      legacy_path: "/product/test-controller",
      target_slug: @product.slug,
      variant_params: { size: "12\"" },
      active: true
    )

    # Sign in as admin
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  # T049: Test index action
  test "should get index" do
    get admin_legacy_redirects_url
    assert_response :success
    assert_select "h1", text: /Legacy Redirects/i
  end

  # T050: Test show action
  test "should show redirect" do
    get admin_legacy_redirect_url(@redirect)
    assert_response :success
    assert_select "td", text: @redirect.legacy_path
  end

  # T051: Test new action
  test "should get new" do
    get new_admin_legacy_redirect_url
    assert_response :success
    assert_select "form"
  end

  # T052: Test create action with valid params
  test "should create redirect" do
    assert_difference("LegacyRedirect.count") do
      post admin_legacy_redirects_url, params: {
        legacy_redirect: {
          legacy_path: "/product/new-redirect",
          target_slug: @product.slug,
          variant_params: { size: "8oz" },
          active: true
        }
      }
    end

    assert_redirected_to admin_legacy_redirect_url(LegacyRedirect.last)
    assert_equal "Redirect created successfully", flash[:notice]
  end

  test "should not create redirect with invalid params" do
    assert_no_difference("LegacyRedirect.count") do
      post admin_legacy_redirects_url, params: {
        legacy_redirect: {
          legacy_path: "",  # Invalid: blank
          target_slug: @product.slug
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # T053: Test edit action
  test "should get edit" do
    get edit_admin_legacy_redirect_url(@redirect)
    assert_response :success
    assert_select "form"
  end

  # T054: Test update action
  test "should update redirect" do
    patch admin_legacy_redirect_url(@redirect), params: {
      legacy_redirect: {
        target_slug: @product.slug,
        active: false
      }
    }

    assert_redirected_to admin_legacy_redirect_url(@redirect)
    assert_equal false, @redirect.reload.active
    assert_equal "Redirect updated successfully", flash[:notice]
  end

  test "should not update redirect with invalid params" do
    patch admin_legacy_redirect_url(@redirect), params: {
      legacy_redirect: {
        legacy_path: ""  # Invalid: blank
      }
    }

    assert_response :unprocessable_entity
  end

  # T055: Test destroy action
  test "should destroy redirect" do
    assert_difference("LegacyRedirect.count", -1) do
      delete admin_legacy_redirect_url(@redirect)
    end

    assert_redirected_to admin_legacy_redirects_url
    assert_equal "Redirect deleted successfully", flash[:notice]
  end

  # T056: Test toggle action
  test "should toggle redirect active status" do
    assert_equal true, @redirect.active

    patch toggle_admin_legacy_redirect_url(@redirect)

    assert_equal false, @redirect.reload.active
    assert_redirected_to admin_legacy_redirects_url
    assert_equal "Redirect deactivated", flash[:notice]
  end

  test "should toggle redirect from inactive to active" do
    @redirect.update!(active: false)

    patch toggle_admin_legacy_redirect_url(@redirect)

    assert_equal true, @redirect.reload.active
    assert_equal "Redirect activated", flash[:notice]
  end

  # T057: Test test action
  test "should show test redirect page" do
    get test_admin_legacy_redirect_url(@redirect)
    assert_response :success
    assert_select "div", text: /Source URL/i
    assert_select "div", text: /Target URL/i
  end

  # T058: Test authentication enforcement
  # TODO: Implement when admin authentication is added to the controller
  # test "should require admin authentication" do
  #   # Log out or clear session
  #   get admin_legacy_redirects_url
  #   assert_redirected_to root_url
  #   assert_equal "You must be an admin to access this page", flash[:alert]
  # end
end
