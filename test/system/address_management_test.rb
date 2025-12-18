require "application_system_test_case"

class AddressManagementTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @address = addresses(:office)
  end

  test "user can view their addresses" do
    sign_in_as(@user)

    visit account_addresses_path

    assert_selector "h1", text: /Addresses/i
    assert_text "Office"
    assert_text "Home"
    assert_text "123 High Street"
    assert_text "45 Residential Road"
  end

  test "user can add a new address" do
    sign_in_as(@user)

    visit account_addresses_path
    click_on "Add new address"

    fill_in "Nickname", with: "Beach House"
    fill_in "Recipient name", with: "Holiday Me"
    fill_in "Company name", with: ""
    fill_in "Address line 1", with: "1 Sandy Beach Road"
    fill_in "Address line 2", with: ""
    fill_in "City", with: "Brighton"
    fill_in "Postcode", with: "BN1 1AA"
    fill_in "Phone", with: "07700111222"

    click_on "Save address"

    assert_text "Beach House"
    assert_text "1 Sandy Beach Road"
    assert_text "Brighton"
  end

  test "user can edit an existing address" do
    sign_in_as(@user)

    visit account_addresses_path

    within("#address_#{@address.id}") do
      click_on "Edit"
    end

    fill_in "Nickname", with: "Main Office"
    fill_in "Recipient name", with: "John Smith Updated"

    click_on "Save address"

    assert_text "Main Office"
    assert_text "John Smith Updated"
  end

  test "user can delete an address" do
    sign_in_as(@user)

    visit account_addresses_path

    home = addresses(:home)
    within("#address_#{home.id}") do
      accept_confirm do
        click_on "Delete"
      end
    end

    assert_no_text "45 Residential Road"
  end

  test "user can set address as default" do
    sign_in_as(@user)

    visit account_addresses_path

    home = addresses(:home)
    within("#address_#{home.id}") do
      click_on "Set as default"
    end

    # Home should now show as default
    within("#address_#{home.id}") do
      assert_text "Default"
    end
  end

  test "validation errors are shown for invalid address" do
    sign_in_as(@user)

    visit new_account_address_path

    # Submit empty form
    click_on "Save address"

    assert_text "can't be blank"
  end

  test "user cannot access addresses without signing in" do
    visit account_addresses_path

    assert_current_path new_session_path
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
    # Wait for redirect after successful sign-in
    assert_current_path root_path
  end
end
