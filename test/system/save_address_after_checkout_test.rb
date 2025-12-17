require "application_system_test_case"

class SaveAddressAfterCheckoutTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @product_variant = product_variants(:one)
  end

  test "save address prompt appears for new address on confirmation page" do
    # This test verifies the save prompt shows when:
    # 1. User is logged in
    # 2. Order address doesn't match any saved addresses

    # Create an order with a new address (not matching user's saved addresses)
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_#{SecureRandom.hex(8)}",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "New Recipient",
      shipping_address_line1: "999 Brand New Street",
      shipping_city: "New City",
      shipping_postal_code: "NC1 1AA",
      shipping_country: "GB"
    )

    sign_in_as(@user)

    # Visit confirmation page
    visit confirmation_order_path(order, token: order.signed_access_token)

    # Should see save address prompt
    assert_selector "[data-testid='save-address-prompt']"
    assert_text "Save this address for faster checkout?"
    assert_text "999 Brand New Street"
  end

  test "save address prompt does not appear when address matches saved address" do
    # User has saved address: addresses(:office) with line1 and postcode
    office = addresses(:office)

    # Create order with matching address
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_#{SecureRandom.hex(8)}",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: office.recipient_name,
      shipping_address_line1: office.line1,
      shipping_city: office.city,
      shipping_postal_code: office.postcode,
      shipping_country: office.country
    )

    sign_in_as(@user)
    visit confirmation_order_path(order, token: order.signed_access_token)

    # Should NOT see save address prompt
    assert_no_selector "[data-testid='save-address-prompt']"
  end

  test "save address prompt does not appear for guest checkout" do
    # Guest order (no user)
    order = Order.create!(
      user: nil,
      email: "guest@example.com",
      status: "paid",
      stripe_session_id: "cs_test_#{SecureRandom.hex(8)}",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Guest User",
      shipping_address_line1: "123 Guest Street",
      shipping_city: "Guest City",
      shipping_postal_code: "GC1 1AA",
      shipping_country: "GB"
    )

    # Visit confirmation page with signed token (proves ownership without session)
    visit confirmation_order_path(order, token: order.signed_access_token)

    # Should NOT see save address prompt (no logged in user)
    assert_no_selector "[data-testid='save-address-prompt']"
  end

  test "user can save address from prompt" do
    # Create order with new address
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_#{SecureRandom.hex(8)}",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Save Me Address",
      shipping_address_line1: "888 Save Street",
      shipping_city: "Save City",
      shipping_postal_code: "SV1 1AA",
      shipping_country: "GB"
    )

    sign_in_as(@user)
    visit confirmation_order_path(order, token: order.signed_access_token)

    # Fill in nickname and save
    fill_in "Nickname", with: "My New Place"
    click_button "Save Address"

    # Should see success and address should be saved
    assert_text "Address saved"

    # Verify address was created
    assert @user.addresses.exists?(line1: "888 Save Street", nickname: "My New Place")
  end

  test "user can dismiss save address prompt" do
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      status: "paid",
      stripe_session_id: "cs_test_#{SecureRandom.hex(8)}",
      subtotal_amount: 10.00,
      vat_amount: 2.00,
      shipping_amount: 5.00,
      total_amount: 17.00,
      shipping_name: "Dismiss Me",
      shipping_address_line1: "777 Dismiss Lane",
      shipping_city: "Dismiss City",
      shipping_postal_code: "DM1 1AA",
      shipping_country: "GB"
    )

    initial_count = @user.addresses.count

    sign_in_as(@user)
    visit confirmation_order_path(order, token: order.signed_access_token)

    # Dismiss the prompt
    click_button "No thanks"

    # Prompt should disappear
    assert_no_selector "[data-testid='save-address-prompt']"

    # Address should NOT be saved
    assert_equal initial_count, @user.addresses.reload.count
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Enter your email", with: user.email_address
    fill_in "Enter your password", with: "password"
    click_button "Sign In"
  end
end
