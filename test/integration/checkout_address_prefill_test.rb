require "test_helper"

class CheckoutAddressPrefillTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @address = addresses(:office)
    @product_variant = products(:one)

    # Track params passed to Stripe APIs using test-local state
    @captured_checkout_params = nil
    @captured_customer_create_params = nil
    @captured_customer_update_params = nil

    # Create a cart with items
    sign_in_as(@user)
    post cart_cart_items_path, params: {
      cart_item: { product_id: @product_variant.id, quantity: 1 }
    }
  end

  test "checkout with address_id creates Stripe Customer and uses it" do
    assert_nil @user.stripe_customer_id

    # Use Mocha to stub Stripe methods - test-scoped, reliable
    mock_session = stub(url: "https://checkout.stripe.com/test/sess_123")
    mock_customer = stub(id: "cus_test_123")

    Stripe::Customer.stubs(:create).with do |params|
      @captured_customer_create_params = params
      true
    end.returns(mock_customer)

    Stripe::Checkout::Session.stubs(:create).with do |params|
      @captured_checkout_params = params
      true
    end.returns(mock_session)

    post checkout_path, params: { address_id: @address.id }

    # Should redirect to Stripe checkout
    assert_response :see_other

    # Verify address_id was stored in session
    assert_equal @address.id.to_s, session[:selected_address_id]

    # Verify Stripe Customer was created
    @user.reload
    assert_equal "cus_test_123", @user.stripe_customer_id

    # Verify checkout used customer (not customer_email) for prefill
    assert_not_nil @captured_checkout_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal "cus_test_123", @captured_checkout_params[:customer]
    assert_nil @captured_checkout_params[:customer_email]
    assert_equal @user.id, @captured_checkout_params[:client_reference_id]
  end

  test "checkout with address syncs shipping address to Stripe Customer" do
    mock_session = stub(url: "https://checkout.stripe.com/test/sess_456")
    mock_customer = stub(id: "cus_test_456")

    Stripe::Customer.stubs(:create).with do |params|
      @captured_customer_create_params = params
      true
    end.returns(mock_customer)

    Stripe::Checkout::Session.stubs(:create).returns(mock_session)

    post checkout_path, params: { address_id: @address.id }

    # Verify shipping was synced to Stripe Customer
    assert_not_nil @captured_customer_create_params, "Expected Stripe::Customer.create to have been called"
    assert_equal @user.email_address, @captured_customer_create_params[:email]
    assert_not_nil @captured_customer_create_params[:shipping]
    assert_equal @address.recipient_name, @captured_customer_create_params[:shipping][:name]
    assert_equal @address.line1, @captured_customer_create_params[:shipping][:address][:line1]
    assert_equal @address.postcode, @captured_customer_create_params[:shipping][:address][:postal_code]
  end

  test "checkout without address_id uses customer_email fallback" do
    mock_session = stub(url: "https://checkout.stripe.com/test/sess_789")

    Stripe::Checkout::Session.stubs(:create).with do |params|
      @captured_checkout_params = params
      true
    end.returns(mock_session)

    post checkout_path

    assert_response :see_other
    assert_nil session[:selected_address_id]

    # Without address selection, user shouldn't have Stripe Customer yet
    @user.reload
    assert_nil @user.stripe_customer_id

    # Should use customer_email fallback
    assert_not_nil @captured_checkout_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal @user.email_address, @captured_checkout_params[:customer_email]
    assert_nil @captured_checkout_params[:customer]
  end

  test "checkout with existing Stripe Customer updates address" do
    # Pre-create a Stripe Customer for the user
    @user.update!(stripe_customer_id: "cus_existing_123")

    mock_session = stub(url: "https://checkout.stripe.com/test/sess_existing")
    mock_customer = stub(id: "cus_existing_123")

    Stripe::Customer.stubs(:update).with do |customer_id, params|
      @captured_customer_update_params = { customer_id: customer_id, params: params }
      true
    end.returns(mock_customer)

    Stripe::Checkout::Session.stubs(:create).with do |params|
      @captured_checkout_params = params
      true
    end.returns(mock_session)

    post checkout_path, params: { address_id: @address.id }

    assert_response :see_other

    # Should have updated existing customer (not created new)
    assert_not_nil @captured_customer_update_params, "Expected Stripe::Customer.update to have been called"
    assert_equal "cus_existing_123", @captured_customer_update_params[:customer_id]
    assert_equal @address.recipient_name, @captured_customer_update_params[:params][:shipping][:name]

    # Checkout should use existing customer ID
    assert_not_nil @captured_checkout_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal "cus_existing_123", @captured_checkout_params[:customer]
  end

  test "checkout with empty address_id uses customer_email (no prefill)" do
    # Even if user has a Stripe Customer, selecting "enter different address"
    # should NOT prefill - use customer_email instead
    @user.update!(stripe_customer_id: "cus_existing_789")

    mock_session = stub(url: "https://checkout.stripe.com/test/sess_empty")

    Stripe::Checkout::Session.stubs(:create).with do |params|
      @captured_checkout_params = params
      true
    end.returns(mock_session)

    post checkout_path, params: { address_id: "" }

    assert_response :see_other
    assert_nil session[:selected_address_id]

    # Should use customer_email, NOT customer (avoids prefill)
    assert_not_nil @captured_checkout_params, "Expected Stripe::Checkout::Session.create to have been called"
    assert_equal @user.email_address, @captured_checkout_params[:customer_email]
    assert_nil @captured_checkout_params[:customer]
  end

  test "guest checkout does not store address selection" do
    sign_out

    # Create a guest cart with items
    post cart_cart_items_path, params: {
      cart_item: { product_id: @product_variant.id, quantity: 1 }
    }

    mock_session = stub(url: "https://checkout.stripe.com/test/sess_guest")
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)

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
