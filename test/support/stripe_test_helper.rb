# StripeTestHelper - Mocha-based helpers for Stripe API testing
#
# Usage in tests:
#   include StripeTestHelper
#
#   setup do
#     stub_stripe_checkout_session
#     stub_stripe_tax_rate
#   end
#
#   test "something" do
#     session = stub_stripe_checkout_session(payment_status: "paid")
#     Stripe::Checkout::Session.stubs(:create).returns(session)
#   end
#
# Access patterns supported:
#   - Hash access via to_hash: session.to_hash[:collected_information][:shipping_details]
#   - Method chaining: session.collected_information.shipping_details.name
#
# NOTE: Mixed access (session.collected_information[:shipping_details]) is NOT supported.
# The controller uses to_hash.with_indifferent_access for defensive hash-based access.

module StripeTestHelper
  # Build a mock Stripe::Checkout::Session with realistic defaults
  # Returns an object that supports both method calls and to_hash conversion
  def build_stripe_session(overrides = {})
    session_id = overrides[:id] || "sess_test_#{SecureRandom.hex(12)}"

    # Build address hash for nested access
    # Use key_provided? pattern to allow explicit nil values for validation testing
    shipping_address = overrides[:shipping_address] || {}
    address_hash = {
      line1: shipping_address.key?(:line1) ? shipping_address[:line1] : "123 Test Street",
      line2: shipping_address.key?(:line2) ? shipping_address[:line2] : "Flat 4",
      city: shipping_address.key?(:city) ? shipping_address[:city] : "London",
      postal_code: shipping_address.key?(:postal_code) ? shipping_address[:postal_code] : "SW1A 1AA",
      country: shipping_address.key?(:country) ? shipping_address[:country] : "GB"
    }

    shipping_name = overrides[:shipping_name] || overrides[:customer_name] || "Test Customer"
    customer_email = overrides[:customer_email] || "test@example.com"
    customer_name = overrides[:customer_name] || "Test Customer"
    shipping_amount = overrides[:shipping_amount_total] || 500

    # Build nested stub objects
    address = stub(
      line1: address_hash[:line1],
      line2: address_hash[:line2],
      city: address_hash[:city],
      postal_code: address_hash[:postal_code],
      country: address_hash[:country]
    )

    shipping_details = stub(
      name: shipping_name,
      address: address
    )

    collected_information = stub(
      shipping_details: shipping_details
    )

    customer_details = stub(
      email: customer_email,
      name: customer_name,
      address: address
    )

    shipping_cost = stub(
      amount_total: shipping_amount
    )

    # Build setup_intent for setup mode sessions
    setup_intent = nil
    if overrides[:mode] == "setup"
      card = stub(brand: "visa", last4: "4242")
      payment_method = stub(id: "pm_test_#{SecureRandom.hex(12)}", card: card)
      setup_intent = stub(id: "seti_test_#{SecureRandom.hex(12)}", payment_method: payment_method)
    end

    # Build total_details for tax information
    tax_amount = overrides[:amount_tax] || 0
    total_details = stub(
      amount_tax: tax_amount
    )

    # Build line_items response (for webhook expansion)
    line_items_data = overrides[:line_items_data] || []
    line_items = stub(data: line_items_data)

    # Calculate amount_total
    amount_total = overrides[:amount_total] || ((overrides[:subtotal] || 0) + tax_amount + shipping_amount)

    # Build the full hash representation (used by controller's to_hash call)
    session_hash = {
      id: session_id,
      url: "https://checkout.stripe.com/test/#{session_id}",
      payment_status: overrides[:payment_status] || "paid",
      customer_details: {
        email: customer_email,
        name: customer_name,
        address: address_hash
      },
      collected_information: {
        shipping_details: {
          name: shipping_name,
          address: address_hash
        }
      },
      shipping_cost: {
        amount_total: shipping_amount
      },
      client_reference_id: overrides[:client_reference_id],
      line_items: overrides[:line_items] || [],
      metadata: overrides[:metadata] || {}
    }

    # Build metadata stub for method access
    metadata_hash = overrides[:metadata] || {}
    metadata_stub = stub(
      cart_id: metadata_hash[:cart_id]
    )

    stub(
      id: session_id,
      url: "https://checkout.stripe.com/test/#{session_id}",
      payment_status: overrides[:payment_status] || "paid",
      customer_details: customer_details,
      collected_information: collected_information,
      shipping_cost: shipping_cost,
      total_details: total_details,
      amount_total: amount_total,
      client_reference_id: overrides[:client_reference_id],
      line_items: line_items,
      setup_intent: setup_intent,
      metadata: metadata_stub,
      to_hash: session_hash
    )
  end

  # Build a mock Stripe::Customer
  def build_stripe_customer(overrides = {})
    stub(
      id: overrides[:id] || "cus_test_#{SecureRandom.hex(12)}",
      email: overrides[:email],
      name: overrides[:name],
      shipping: overrides[:shipping],
      metadata: overrides[:metadata] || {}
    )
  end

  # Build a mock Stripe::TaxRate
  def build_stripe_tax_rate(overrides = {})
    stub(
      id: overrides[:id] || "txr_test_#{SecureRandom.hex(8)}",
      display_name: overrides[:display_name] || "VAT",
      percentage: overrides[:percentage] || 20.0,
      country: overrides[:country] || "GB",
      jurisdiction: overrides[:jurisdiction] || "United Kingdom",
      description: overrides[:description] || "Value Added Tax",
      inclusive: overrides[:inclusive] || false
    )
  end

  # Build a mock Stripe::PaymentIntent
  def build_stripe_payment_intent(overrides = {})
    stub(
      id: overrides[:id] || "pi_test_#{SecureRandom.hex(12)}",
      status: overrides[:status] || "succeeded",
      amount: overrides[:amount],
      currency: overrides[:currency] || "gbp",
      customer: overrides[:customer],
      payment_method: overrides[:payment_method],
      metadata: overrides[:metadata] || {},
      description: overrides[:description]
    )
  end

  # Build a mock Stripe::Refund
  def build_stripe_refund(overrides = {})
    stub(
      id: overrides[:id] || "re_test_#{SecureRandom.hex(12)}",
      status: overrides[:status] || "succeeded",
      payment_intent: overrides[:payment_intent],
      amount: overrides[:amount]
    )
  end

  # Build a mock Stripe list response
  def build_stripe_list(data)
    stub(data: data)
  end

  # Stub Stripe::Checkout::Session.create to return a session
  # Returns the mock session for further assertions
  def stub_stripe_session_create(session_overrides = {}, &block)
    session = build_stripe_session(session_overrides)

    if block_given?
      Stripe::Checkout::Session.stubs(:create).with(&block).returns(session)
    else
      Stripe::Checkout::Session.stubs(:create).returns(session)
    end

    session
  end

  # Stub Stripe::Checkout::Session.retrieve to return a session
  def stub_stripe_session_retrieve(session_overrides = {})
    session = build_stripe_session(session_overrides)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)
    session
  end

  # Stub Stripe::TaxRate.list to return UK VAT
  def stub_stripe_tax_rate_list
    tax_rate = build_stripe_tax_rate
    Stripe::TaxRate.stubs(:list).returns(build_stripe_list([ tax_rate ]))
    tax_rate
  end

  # Stub Stripe::Customer.create
  def stub_stripe_customer_create(customer_overrides = {}, &block)
    customer = build_stripe_customer(customer_overrides)

    if block_given?
      Stripe::Customer.stubs(:create).with(&block).returns(customer)
    else
      Stripe::Customer.stubs(:create).returns(customer)
    end

    customer
  end

  # Stub Stripe::Customer.update
  def stub_stripe_customer_update(customer_overrides = {})
    customer = build_stripe_customer(customer_overrides)
    Stripe::Customer.stubs(:update).returns(customer)
    customer
  end

  # Stub Stripe::Customer.retrieve
  def stub_stripe_customer_retrieve(customer_overrides = {})
    customer = build_stripe_customer(customer_overrides)
    Stripe::Customer.stubs(:retrieve).returns(customer)
    customer
  end

  # Stub Stripe::PaymentIntent.create
  def stub_stripe_payment_intent_create(intent_overrides = {}, &block)
    intent = build_stripe_payment_intent(intent_overrides)

    if block_given?
      Stripe::PaymentIntent.stubs(:create).with(&block).returns(intent)
    else
      Stripe::PaymentIntent.stubs(:create).returns(intent)
    end

    intent
  end

  # Build a mock Stripe webhook event
  def build_stripe_webhook_event(type:, data_object:)
    stub(
      type: type,
      data: stub(object: data_object)
    )
  end

  # Stub Stripe::Webhook.construct_event for webhook testing
  def stub_stripe_webhook_construct_event(event)
    Stripe::Webhook.stubs(:construct_event).returns(event)
    event
  end

  # Common Stripe errors for testing error handling
  module StripeErrors
    def self.card_declined
      Stripe::CardError.new("Your card was declined.", "card_declined", http_status: 402)
    end

    def self.invalid_request(message = "Invalid request")
      Stripe::InvalidRequestError.new(message, nil, http_status: 400)
    end

    def self.api_connection_error
      Stripe::APIConnectionError.new("Failed to connect to Stripe API")
    end

    def self.api_error
      Stripe::APIError.new("An error occurred with our API")
    end

    def self.rate_limit_error
      Stripe::RateLimitError.new("Too many requests")
    end
  end
end
