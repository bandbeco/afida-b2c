require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_attributes = {
      email_address: "test@example.com",
      password: "SecurePassword123",
      password_confirmation: "SecurePassword123"
    }
  end

  # Validation tests
  test "validates presence of email_address" do
    user = User.new(@valid_attributes.except(:email_address))
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "validates uniqueness of email_address" do
    user = User.new(@valid_attributes.merge(email_address: @user.email_address))
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "normalizes email_address to lowercase" do
    user = User.create!(@valid_attributes.merge(email_address: "TEST@EXAMPLE.COM"))
    assert_equal "test@example.com", user.email_address
  end

  test "strips whitespace from email_address" do
    user = User.create!(@valid_attributes.merge(email_address: "  test@example.com  "))
    assert_equal "test@example.com", user.email_address
  end

  # Password tests (has_secure_password)
  test "requires password for new users" do
    user = User.new(email_address: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "requires password to be at least 8 characters" do
    user = User.new(
      email_address: "short@example.com",
      password: "short",
      password_confirmation: "short"
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "accepts password with exactly 8 characters" do
    user = User.new(
      email_address: "exact8@example.com",
      password: "exactly8",
      password_confirmation: "exactly8"
    )
    assert user.valid?
  end

  test "allows update without password when password is blank" do
    user = User.create!(
      email_address: "update@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    user.first_name = "Updated"
    assert user.valid?
  end

  test "requires password_confirmation to match" do
    user = User.new(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "different"
    )
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "authenticates with correct password" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.authenticate("password123")
  end

  test "does not authenticate with incorrect password" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.authenticate("wrongpassword")
  end

  # Role tests
  test "admin? returns true when role is admin" do
    @user.role = "admin"
    assert @user.admin?
  end

  test "admin? returns false when role is not admin" do
    @user.role = "user"
    assert_not @user.admin?
  end

  test "admin? returns false when role is nil" do
    @user.role = nil
    assert_not @user.admin?
  end

  # Initials tests
  test "initials returns first letters of first and last name when present" do
    @user.first_name = "John"
    @user.last_name = "Doe"
    assert_equal "JD", @user.initials
  end

  test "initials returns uppercase first letters" do
    @user.first_name = "jane"
    @user.last_name = "smith"
    assert_equal "JS", @user.initials
  end

  test "initials extracts from email when names are blank" do
    @user.first_name = nil
    @user.last_name = nil
    @user.email_address = "john.doe@example.com"
    assert_equal "JD", @user.initials
  end

  test "initials extracts from email when only first_name is present" do
    @user.first_name = "John"
    @user.last_name = nil
    @user.email_address = "john.doe@example.com"
    assert_equal "JD", @user.initials
  end

  test "initials extracts from email when only last_name is present" do
    @user.first_name = nil
    @user.last_name = "Doe"
    @user.email_address = "john.doe@example.com"
    assert_equal "JD", @user.initials
  end

  test "initials handles simple email format" do
    @user.first_name = nil
    @user.last_name = nil
    @user.email_address = "test@example.com"
    assert_equal "T", @user.initials
  end

  # Email verification tests
  test "verify_email_address! sets email_address_verified to true" do
    @user.email_address_verified = false
    @user.verify_email_address!
    assert @user.email_address_verified
  end

  test "verify_email_address! persists to database" do
    @user.email_address_verified = false
    @user.verify_email_address!
    @user.reload
    assert @user.email_address_verified
  end

  test "email_address_verification_token generates a token" do
    token = @user.email_address_verification_token
    assert_not_nil token
    assert_kind_of String, token
  end

  test "find_by_email_address_verification_token! finds user with valid token" do
    token = @user.email_address_verification_token
    found_user = User.find_by_email_address_verification_token!(token)
    assert_equal @user, found_user
  end

  test "find_by_email_address_verification_token! raises error with invalid token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_email_address_verification_token!("invalid_token")
    end
  end

  # Association tests
  test "has many sessions" do
    assert_respond_to @user, :sessions
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.sessions
  end

  test "has many carts" do
    assert_respond_to @user, :carts
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.carts
  end

  test "has many orders" do
    assert_respond_to @user, :orders
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.orders
  end

  test "destroying user destroys associated sessions" do
    user = User.create!(@valid_attributes.merge(email_address: "sessions@example.com"))
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")

    assert_difference "Session.count", -1 do
      user.destroy
    end
  end

  test "destroying user destroys associated carts" do
    user = User.create!(@valid_attributes.merge(email_address: "carts@example.com"))
    cart = user.carts.create!

    assert_difference "Cart.count", -1 do
      user.destroy
    end
  end

  test "destroying user destroys associated orders" do
    user = User.create!(@valid_attributes.merge(email_address: "orders@example.com"))
    order = user.orders.create!(
      email: "orders@example.com",
      stripe_session_id: "sess_test_destroy",
      order_number: "ORD-2025-111111",
      status: "pending",
      subtotal_amount: 100,
      vat_amount: 20,
      shipping_amount: 5,
      total_amount: 125,
      shipping_name: "John Doe",
      shipping_address_line1: "123 Main St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    )

    assert_difference "Order.count", -1 do
      user.destroy
    end
  end

  # Organization and role tests
  test "user can belong to organization" do
    user = users(:acme_owner)
    assert_equal organizations(:acme), user.organization
  end

  test "user with organization must have role" do
    user = User.new(
      email_address: "test@example.com",
      password: "password123",
      organization: organizations(:acme),
      role: nil
    )
    assert_not user.valid?
    assert_includes user.errors[:role], "can't be blank"
  end

  test "user without organization can have nil role" do
    user = User.new(
      email_address: "newconsumer@example.com",
      password: "password123",
      organization: nil,
      role: nil
    )
    assert user.valid?
  end

  test "valid roles are owner, admin, member" do
    user = users(:acme_owner)

    user.role = "owner"
    assert user.valid?

    user.role = "admin"
    assert user.valid?

    user.role = "member"
    assert user.valid?

    user.role = "invalid"
    assert_not user.valid?
  end

  test "organization can have only one owner" do
    # First owner already exists in fixtures (acme_owner)
    existing_owner = users(:acme_owner)
    assert_equal "owner", existing_owner.role

    # Second owner should fail
    owner2 = User.new(
      email_address: "owner2@acme.com",
      password: "password123",
      organization: organizations(:acme),
      role: "owner"
    )
    assert_not owner2.valid?
    assert_includes owner2.errors[:role], "organization already has an owner"
  end
end
