require "test_helper"

class Organizations::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @acme_admin = users(:acme_admin)
    @acme_member = users(:acme_member)
    @consumer = users(:consumer)
  end

  test "redirects non-organization users" do
    sign_in_as @consumer

    get organizations_products_path
    assert_redirected_to root_path
    assert_equal "You must be a member of an organization to access this page", flash[:alert]
  end

  test "shows organization's customized products" do
    sign_in_as @acme_admin

    get organizations_products_path
    assert_response :success

    assert_select "h1", "Your Branded Products"
    assert_select "div.product-card", count: 2 # acme's customized products
  end

  test "does not show other organizations' products" do
    sign_in_as users(:bobs_owner)

    get organizations_products_path
    assert_response :success

    # Should not see ACME's products
    assert_select "div.product-card", count: 0
  end

  test "all organization members can access" do
    [ @acme_admin, @acme_member ].each do |user|
      sign_in_as user

      get organizations_products_path
      assert_response :success
    end
  end

  test "shows empty state when no products" do
    sign_in_as users(:bobs_owner)

    get organizations_products_path
    assert_response :success

    assert_select "div.empty-state"
    assert_select "a[href=?]", products_path
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
