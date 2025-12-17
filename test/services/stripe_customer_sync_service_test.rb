require "test_helper"

class StripeCustomerSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @address = addresses(:office)
    FakeStripe.reset!
  end

  test "creates new Stripe Customer when user has no stripe_customer_id" do
    assert_nil @user.stripe_customer_id

    result = StripeCustomerSyncService.sync(@user, address: @address)

    assert_not_nil result
    assert result.start_with?("cus_test_")

    @user.reload
    assert_equal result, @user.stripe_customer_id
  end

  test "syncs email to new Stripe Customer" do
    StripeCustomerSyncService.sync(@user, address: @address)

    customer_params = FakeStripe::Customer.last_create_params
    assert_equal @user.email_address, customer_params[:email]
  end

  test "syncs address as shipping to new Stripe Customer" do
    StripeCustomerSyncService.sync(@user, address: @address)

    customer_params = FakeStripe::Customer.last_create_params
    shipping = customer_params[:shipping]

    assert_not_nil shipping
    assert_equal @address.recipient_name, shipping[:name]
    assert_equal @address.line1, shipping[:address][:line1]
    assert_equal @address.city, shipping[:address][:city]
    assert_equal @address.postcode, shipping[:address][:postal_code]
    assert_equal @address.country, shipping[:address][:country]
  end

  test "updates existing Stripe Customer when user has stripe_customer_id" do
    @user.update!(stripe_customer_id: "cus_existing_456")
    FakeStripe::Customer.new(id: "cus_existing_456", email: @user.email_address)

    result = StripeCustomerSyncService.sync(@user, address: @address)

    # Should return existing customer ID
    assert_equal "cus_existing_456", result

    # Should have called update, not create
    update_params = FakeStripe::Customer.last_update_params
    assert_not_nil update_params
    assert_equal "cus_existing_456", update_params[:customer_id]
    assert_equal @address.recipient_name, update_params[:params][:shipping][:name]
  end

  test "uses default_address when no address specified" do
    @address.update!(default: true)

    StripeCustomerSyncService.sync(@user)

    customer_params = FakeStripe::Customer.last_create_params
    assert_equal @address.line1, customer_params[:shipping][:address][:line1]
  end

  test "includes user metadata" do
    StripeCustomerSyncService.sync(@user, address: @address)

    customer_params = FakeStripe::Customer.last_create_params
    assert_equal @user.id, customer_params[:metadata][:user_id]
  end

  test "handles user without address" do
    # Create user without any addresses
    user_without_address = User.create!(
      email_address: "noaddress@example.com",
      password: "password123"
    )

    result = StripeCustomerSyncService.sync(user_without_address)

    assert_not_nil result
    customer_params = FakeStripe::Customer.last_create_params
    assert_nil customer_params[:shipping]
  end
end
