require "test_helper"

class AddressTest < ActiveSupport::TestCase
  # Validation tests
  test "valid address with all required fields" do
    address = Address.new(
      user: users(:one),
      nickname: "Test",
      recipient_name: "Test User",
      line1: "123 Test Street",
      city: "London",
      postcode: "SW1A 1AA",
      country: "GB"
    )
    assert address.valid?
  end

  test "invalid without nickname" do
    address = addresses(:office)
    address.nickname = nil
    assert_not address.valid?
    assert_includes address.errors[:nickname], "can't be blank"
  end

  test "invalid without recipient_name" do
    address = addresses(:office)
    address.recipient_name = nil
    assert_not address.valid?
    assert_includes address.errors[:recipient_name], "can't be blank"
  end

  test "invalid without line1" do
    address = addresses(:office)
    address.line1 = nil
    assert_not address.valid?
    assert_includes address.errors[:line1], "can't be blank"
  end

  test "invalid without city" do
    address = addresses(:office)
    address.city = nil
    assert_not address.valid?
    assert_includes address.errors[:city], "can't be blank"
  end

  test "invalid without postcode" do
    address = addresses(:office)
    address.postcode = nil
    assert_not address.valid?
    assert_includes address.errors[:postcode], "can't be blank"
  end

  test "invalid without country" do
    address = addresses(:office)
    address.country = nil
    assert_not address.valid?
    assert_includes address.errors[:country], "can't be blank"
  end

  test "nickname length must not exceed 50 characters" do
    address = addresses(:office)
    address.nickname = "a" * 51
    assert_not address.valid?
    assert_includes address.errors[:nickname], "is too long (maximum is 50 characters)"
  end

  test "recipient_name length must not exceed 100 characters" do
    address = addresses(:office)
    address.recipient_name = "a" * 101
    assert_not address.valid?
    assert_includes address.errors[:recipient_name], "is too long (maximum is 100 characters)"
  end

  # Default flag tests
  test "setting an address as default unsets other defaults for same user" do
    user = users(:one)
    office = addresses(:office)
    home = addresses(:home)

    assert office.default?
    assert_not home.default?

    home.update!(default: true)
    office.reload

    assert home.default?
    assert_not office.default?
  end

  test "setting default does not affect other users addresses" do
    user_one = users(:one)
    user_two = users(:two)

    # Create a default address for user_two
    user_two_address = user_two.addresses.create!(
      nickname: "Office",
      recipient_name: "User Two",
      line1: "999 Other Street",
      city: "Leeds",
      postcode: "LS1 1AA",
      country: "GB",
      default: true
    )

    # Changing user_one's default should not affect user_two
    addresses(:home).update!(default: true)

    user_two_address.reload
    assert user_two_address.default?
  end

  # Scope tests
  test "default_first scope orders addresses with default first" do
    user = users(:one)
    ordered = user.addresses.default_first

    assert_equal addresses(:office), ordered.first
    assert_equal addresses(:home), ordered.second
  end

  # Callback tests
  test "deleting default address assigns new default to oldest remaining" do
    user = users(:one)
    office = addresses(:office)
    home = addresses(:home)

    assert office.default?
    assert_not home.default?

    office.destroy!
    home.reload

    assert home.default?
  end

  test "deleting non-default address does not change default" do
    user = users(:one)
    office = addresses(:office)
    home = addresses(:home)

    assert office.default?
    home.destroy!
    office.reload

    assert office.default?
  end

  test "deleting only address leaves no default" do
    user = users(:two)
    warehouse = addresses(:warehouse)

    warehouse.destroy!

    assert_not user.addresses.exists?
    assert_nil user.default_address
  end

  # User association tests
  test "user has_saved_addresses? returns true when addresses exist" do
    user = users(:one)
    assert user.has_saved_addresses?
  end

  test "user has_saved_addresses? returns false when no addresses" do
    user = users(:one)
    user.addresses.destroy_all
    assert_not user.has_saved_addresses?
  end

  test "user default_address returns default address" do
    user = users(:one)
    assert_equal addresses(:office), user.default_address
  end

  test "user default_address returns oldest when no default set" do
    user = users(:one)
    user.addresses.update_all(default: false)

    # Oldest by created_at should be returned
    oldest = user.addresses.order(:created_at).first
    assert_equal oldest, user.default_address
  end

  test "user has_matching_address? returns true for matching line1 and postcode" do
    user = users(:one)
    assert user.has_matching_address?(line1: "123 High Street", postcode: "SW1A 1AA")
  end

  test "user has_matching_address? returns false for non-matching address" do
    user = users(:one)
    assert_not user.has_matching_address?(line1: "999 Unknown Road", postcode: "XX1 1XX")
  end

  # Dependent destroy test
  test "destroying user destroys all addresses" do
    user = users(:one)
    address_ids = user.addresses.pluck(:id)

    assert address_ids.present?

    user.destroy!

    address_ids.each do |id|
      assert_nil Address.find_by(id: id)
    end
  end
end
