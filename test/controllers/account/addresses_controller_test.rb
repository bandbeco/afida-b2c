require "test_helper"

class Account::AddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @address = addresses(:office)
    sign_in_as(@user)
  end

  # Index
  test "should get index" do
    get account_addresses_url
    assert_response :success
    assert_select "h1", /Addresses/i
  end

  test "index requires authentication" do
    sign_out
    get account_addresses_url
    assert_redirected_to new_session_url
  end

  test "index shows only current user addresses" do
    get account_addresses_url
    assert_response :success

    # User one's addresses should be visible
    assert_match "Office", response.body
    assert_match "Home", response.body

    # User two's address should not be visible
    assert_no_match "Warehouse", response.body
  end

  # New
  test "should get new" do
    get new_account_address_url
    assert_response :success
    assert_select "form"
  end

  test "new requires authentication" do
    sign_out
    get new_account_address_url
    assert_redirected_to new_session_url
  end

  # Create
  test "should create address" do
    assert_difference("Address.count") do
      post account_addresses_url, params: {
        address: {
          nickname: "New Office",
          recipient_name: "Test User",
          company_name: "Test Co",
          line1: "999 New Street",
          line2: "Suite 100",
          city: "London",
          postcode: "EC1A 1AA",
          phone: "07700999888",
          default: false
        }
      }
    end

    assert_redirected_to account_addresses_url
    follow_redirect!
    assert_match "New Office", response.body
  end

  test "should create address and set as default" do
    post account_addresses_url, params: {
      address: {
        nickname: "Primary",
        recipient_name: "Test User",
        line1: "888 Main Street",
        city: "London",
        postcode: "EC1A 1BB",
        default: true
      }
    }

    new_address = Address.find_by(nickname: "Primary")
    assert new_address.default?

    # Old default should be unset
    @address.reload
    assert_not @address.default?
  end

  test "create with invalid data re-renders form" do
    assert_no_difference("Address.count") do
      post account_addresses_url, params: {
        address: {
          nickname: "",
          recipient_name: "",
          line1: "",
          city: "",
          postcode: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create requires authentication" do
    sign_out
    post account_addresses_url, params: { address: { nickname: "Test" } }
    assert_redirected_to new_session_url
  end

  # Edit
  test "should get edit" do
    get edit_account_address_url(@address)
    assert_response :success
    assert_select "form"
    assert_select "input[value='Office']"
  end

  test "edit requires authentication" do
    sign_out
    get edit_account_address_url(@address)
    assert_redirected_to new_session_url
  end

  test "cannot edit another user address" do
    other_address = addresses(:warehouse)
    get edit_account_address_url(other_address)
    assert_response :not_found
  end

  # Update
  test "should update address" do
    patch account_address_url(@address), params: {
      address: {
        nickname: "Updated Office",
        recipient_name: "Updated Name"
      }
    }

    assert_redirected_to account_addresses_url
    @address.reload
    assert_equal "Updated Office", @address.nickname
    assert_equal "Updated Name", @address.recipient_name
  end

  test "update with invalid data re-renders form" do
    patch account_address_url(@address), params: {
      address: { nickname: "" }
    }

    assert_response :unprocessable_entity
  end

  test "cannot update another user address" do
    other_address = addresses(:warehouse)
    patch account_address_url(other_address), params: {
      address: { nickname: "Hacked" }
    }

    assert_response :not_found
    other_address.reload
    assert_equal "Warehouse", other_address.nickname
  end

  # Destroy
  test "should destroy address" do
    assert_difference("Address.count", -1) do
      delete account_address_url(@address)
    end

    assert_redirected_to account_addresses_url
  end

  test "destroying default address assigns new default" do
    home = addresses(:home)
    assert @address.default?
    assert_not home.default?

    delete account_address_url(@address)

    home.reload
    assert home.default?
  end

  test "cannot destroy another user address" do
    other_address = addresses(:warehouse)
    assert_no_difference("Address.count") do
      delete account_address_url(other_address)
    end

    assert_response :not_found
  end

  # Set Default
  test "should set default" do
    home = addresses(:home)
    assert @address.default?
    assert_not home.default?

    patch set_default_account_address_url(home)

    assert_redirected_to account_addresses_url
    home.reload
    @address.reload
    assert home.default?
    assert_not @address.default?
  end

  test "cannot set default on another user address" do
    other_address = addresses(:warehouse)
    patch set_default_account_address_url(other_address)

    assert_response :not_found
  end

  # Create from Order
  test "should create address from order" do
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_create_from_order",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Order Recipient",
      shipping_address_line1: "123 Order Street",
      shipping_address_line2: "Apt 4B",
      shipping_city: "Order City",
      shipping_postal_code: "OC1 1AA",
      shipping_country: "GB"
    )

    assert_difference("Address.count") do
      post create_from_order_account_addresses_url, params: {
        order_id: order.id,
        nickname: "From Order"
      }
    end

    new_address = Address.last
    assert_equal "From Order", new_address.nickname
    assert_equal "Order Recipient", new_address.recipient_name
    assert_equal "123 Order Street", new_address.line1
    assert_equal "Apt 4B", new_address.line2
    assert_equal "Order City", new_address.city
    assert_equal "OC1 1AA", new_address.postcode
    assert_equal "GB", new_address.country
    assert_equal @user.id, new_address.user_id
  end

  test "create_from_order requires authentication" do
    sign_out
    post create_from_order_account_addresses_url, params: {
      order_id: 1,
      nickname: "Test"
    }
    assert_redirected_to new_session_url
  end

  test "create_from_order rejects order not belonging to user" do
    other_user = users(:two)
    other_order = Order.create!(
      user: other_user,
      email: other_user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_other_user",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Other User",
      shipping_address_line1: "456 Other Street",
      shipping_city: "Other City",
      shipping_postal_code: "OT1 1AA",
      shipping_country: "GB"
    )

    assert_no_difference("Address.count") do
      post create_from_order_account_addresses_url, params: {
        order_id: other_order.id,
        nickname: "Stolen"
      }
    end

    assert_response :not_found
  end

  test "create_from_order requires nickname" do
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_no_nickname",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Test",
      shipping_address_line1: "123 Test Street",
      shipping_city: "Test City",
      shipping_postal_code: "TS1 1AA",
      shipping_country: "GB"
    )

    assert_no_difference("Address.count") do
      post create_from_order_account_addresses_url, params: {
        order_id: order.id,
        nickname: ""
      }
    end

    # Redirects with alert on validation failure
    assert_redirected_to confirmation_order_path(order)
    follow_redirect!
    assert_match "Could not save address", flash[:alert]
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end
end
