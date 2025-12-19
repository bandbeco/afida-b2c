require "test_helper"

class StripeCustomerSyncServiceTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @user = users(:one)
    @address = addresses(:office)
    @captured_create_params = nil
    @captured_update_params = nil
  end

  test "creates new Stripe Customer when user has no stripe_customer_id" do
    assert_nil @user.stripe_customer_id

    customer = build_stripe_customer(id: "cus_new_123")
    Stripe::Customer.stubs(:create).returns(customer)

    result = StripeCustomerSyncService.sync(@user, address: @address)

    assert_not_nil result
    assert_equal "cus_new_123", result

    @user.reload
    assert_equal "cus_new_123", @user.stripe_customer_id
  end

  test "syncs email to new Stripe Customer" do
    customer = build_stripe_customer(id: "cus_test_email")
    Stripe::Customer.stubs(:create).with do |params|
      @captured_create_params = params
      true
    end.returns(customer)

    StripeCustomerSyncService.sync(@user, address: @address)

    assert_equal @user.email_address, @captured_create_params[:email]
  end

  test "syncs address as shipping to new Stripe Customer" do
    customer = build_stripe_customer(id: "cus_test_shipping")
    Stripe::Customer.stubs(:create).with do |params|
      @captured_create_params = params
      true
    end.returns(customer)

    StripeCustomerSyncService.sync(@user, address: @address)

    shipping = @captured_create_params[:shipping]

    assert_not_nil shipping
    assert_equal @address.recipient_name, shipping[:name]
    assert_equal @address.line1, shipping[:address][:line1]
    assert_equal @address.city, shipping[:address][:city]
    assert_equal @address.postcode, shipping[:address][:postal_code]
    assert_equal @address.country, shipping[:address][:country]
  end

  test "updates existing Stripe Customer when user has stripe_customer_id" do
    @user.update!(stripe_customer_id: "cus_existing_456")

    existing_customer = build_stripe_customer(id: "cus_existing_456", email: @user.email_address)
    Stripe::Customer.stubs(:retrieve).returns(existing_customer)
    Stripe::Customer.stubs(:update).with do |customer_id, params|
      @captured_update_params = { customer_id: customer_id, params: params }
      true
    end.returns(existing_customer)

    result = StripeCustomerSyncService.sync(@user, address: @address)

    # Should return existing customer ID
    assert_equal "cus_existing_456", result

    # Should have called update, not create
    assert_not_nil @captured_update_params
    assert_equal "cus_existing_456", @captured_update_params[:customer_id]
    assert_equal @address.recipient_name, @captured_update_params[:params][:shipping][:name]
  end

  test "uses default_address when no address specified" do
    @address.update!(default: true)

    customer = build_stripe_customer(id: "cus_test_default")
    Stripe::Customer.stubs(:create).with do |params|
      @captured_create_params = params
      true
    end.returns(customer)

    StripeCustomerSyncService.sync(@user)

    assert_equal @address.line1, @captured_create_params[:shipping][:address][:line1]
  end

  test "includes user metadata" do
    customer = build_stripe_customer(id: "cus_test_meta")
    Stripe::Customer.stubs(:create).with do |params|
      @captured_create_params = params
      true
    end.returns(customer)

    StripeCustomerSyncService.sync(@user, address: @address)

    assert_equal @user.id, @captured_create_params[:metadata][:user_id]
  end

  test "handles user without address" do
    # Create user without any addresses
    user_without_address = User.create!(
      email_address: "noaddress@example.com",
      password: "password123"
    )

    customer = build_stripe_customer(id: "cus_no_address")
    Stripe::Customer.stubs(:create).with do |params|
      @captured_create_params = params
      true
    end.returns(customer)

    result = StripeCustomerSyncService.sync(user_without_address)

    assert_not_nil result
    assert_nil @captured_create_params[:shipping]
  end
end
