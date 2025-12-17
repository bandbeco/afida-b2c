require "test_helper"

class CheckoutAddressPrefillTest < ActionDispatch::IntegrationTest
  # Use the real Stripe gem classes for stubbing (bypass FakeStripe constants)
  REAL_STRIPE_CUSTOMER = ::Stripe::Customer
  REAL_STRIPE_CHECKOUT_SESSION = ::Stripe::Checkout::Session

  setup do
    @user = users(:one)
    @address = addresses(:office)
    @product_variant = product_variants(:one)

    # Reset FakeStripe state before each test
    FakeStripe.reset!

    # Create a cart with items
    sign_in_as(@user)
    post cart_cart_items_path, params: {
      cart_item: { product_variant_id: @product_variant.id, quantity: 1 }
    }
  end

  test "checkout with address_id creates Stripe Customer and uses it" do
    assert_nil @user.stripe_customer_id

    post checkout_path, params: { address_id: @address.id }

    # Should redirect to Stripe checkout
    assert_response :see_other

    # Verify address_id was stored in session
    assert_equal @address.id.to_s, session[:selected_address_id]

    # Verify Stripe Customer was created
    @user.reload
    assert_not_nil @user.stripe_customer_id

    # Verify checkout used customer (not customer_email) for prefill
    stripe_params = FakeStripe::CheckoutSession.last_create_params
    assert_not_nil stripe_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal @user.stripe_customer_id, stripe_params[:customer]
    assert_nil stripe_params[:customer_email]
    assert_equal @user.id, stripe_params[:client_reference_id]
  end

  test "checkout with address syncs shipping address to Stripe Customer" do
    post checkout_path, params: { address_id: @address.id }

    # Verify shipping was synced to Stripe Customer
    customer_params = FakeStripe::Customer.last_create_params
    assert_not_nil customer_params, "Expected Stripe::Customer.create to have been called"
    assert_equal @user.email_address, customer_params[:email]
    assert_not_nil customer_params[:shipping]
    assert_equal @address.recipient_name, customer_params[:shipping][:name]
    assert_equal @address.line1, customer_params[:shipping][:address][:line1]
    assert_equal @address.postcode, customer_params[:shipping][:address][:postal_code]
  end

  test "checkout without address_id uses customer_email fallback" do
    post checkout_path

    assert_response :see_other
    assert_nil session[:selected_address_id]

    # Without address selection, user shouldn't have Stripe Customer yet
    @user.reload
    assert_nil @user.stripe_customer_id

    # Should use customer_email fallback
    stripe_params = FakeStripe::CheckoutSession.last_create_params
    assert_not_nil stripe_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal @user.email_address, stripe_params[:customer_email]
    assert_nil stripe_params[:customer]
  end

  test "checkout with existing Stripe Customer updates address" do
    # Pre-create a Stripe Customer for the user
    @user.update!(stripe_customer_id: "cus_existing_123")
    FakeStripe::Customer.new(id: "cus_existing_123", email: @user.email_address)

    post checkout_path, params: { address_id: @address.id }

    assert_response :see_other

    # Should have updated existing customer (not created new)
    update_params = FakeStripe::Customer.last_update_params
    assert_not_nil update_params, "Expected Stripe::Customer.update to have been called"
    assert_equal "cus_existing_123", update_params[:customer_id]
    assert_equal @address.recipient_name, update_params[:params][:shipping][:name]

    # Checkout should use existing customer ID
    stripe_params = FakeStripe::CheckoutSession.last_create_params
    assert_not_nil stripe_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal "cus_existing_123", stripe_params[:customer]
  end

  test "checkout with empty address_id uses customer_email (no prefill)" do
    # Even if user has a Stripe Customer, selecting "enter different address"
    # should NOT prefill - use customer_email instead
    @user.update!(stripe_customer_id: "cus_existing_789")

    post checkout_path, params: { address_id: "" }

    assert_response :see_other
    assert_nil session[:selected_address_id]

    # Should use customer_email, NOT customer (avoids prefill)
    stripe_params = FakeStripe::CheckoutSession.last_create_params
    assert_not_nil stripe_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal @user.email_address, stripe_params[:customer_email]
    assert_nil stripe_params[:customer]
  end

  test "guest checkout does not store address selection" do
    sign_out

    # Create a guest cart with items
    post cart_cart_items_path, params: {
      cart_item: { product_variant_id: @product_variant.id, quantity: 1 }
    }

    post checkout_path

    assert_response :see_other
    assert_nil session[:selected_address_id]
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end
end
