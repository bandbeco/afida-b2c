# FakeStripe - Plain Old Ruby Object for Stripe API testing
#
# This provides realistic mock implementations of Stripe API objects
# without hitting the real Stripe API. Can be used in both test and
# development environments.
#
# Usage in tests:
#   # Already configured in test_helper.rb
#   session = Stripe::Checkout::Session.create(...)
#   session.url # => "https://checkout.stripe.com/test/sess_..."
#
# Usage in development:
#   # Set USE_FAKE_STRIPE=true in .env or environment
#   # Allows testing checkout flow without real Stripe API calls

module FakeStripe
  # Reset all stored state (call in test setup)
  def self.reset!
    CheckoutSession.reset!
    TaxRate.reset!
    Subscription.reset!
    Customer.reset!
    PaymentIntent.reset!
  end

  # Configure default behavior
  def self.configure
    yield self
  end

  class CheckoutSession
    attr_reader :id, :url, :payment_status, :customer_details, :collected_information,
                :shipping_cost, :client_reference_id, :line_items

    @@sessions = {}
    @@next_id = 1
    @@last_create_params = nil

    # Access the params passed to the most recent create call (for testing)
    def self.last_create_params
      @@last_create_params
    end

    def initialize(params = {})
      @id = "sess_test_#{SecureRandom.hex(12)}"
      @url = "https://checkout.stripe.com/test/#{@id}"
      @payment_status = params[:payment_status] || "paid"
      @client_reference_id = params[:client_reference_id]
      @line_items = params[:line_items] || []

      # Build customer details from params or use defaults (billing info)
      email = params[:customer_email] || "test@example.com"
      @customer_details = CustomerDetails.new(
        email: email,
        name: params[:customer_name] || "Test Customer",
        address: {
          line1: "123 Test Street",
          line2: "Flat 4",
          city: "London",
          postal_code: "SW1A 1AA",
          country: "GB"
        }
      )

      # Build collected_information with shipping_details (Stripe API 2025-03-31+)
      # https://docs.stripe.com/changelog/basil/2025-03-31/checkout-session-remove-shipping-details
      # Use customer_name as fallback for shipping name (backward compat with existing tests)
      @collected_information = CollectedInformation.new(
        shipping_details: ShippingDetails.new(
          name: params[:shipping_name] || params[:customer_name] || "Test Customer",
          address: {
            line1: "123 Test Street",
            line2: "Flat 4",
            city: "London",
            postal_code: "SW1A 1AA",
            country: "GB"
          }
        )
      )

      # Default shipping cost (£5.00 = 500 pence)
      @shipping_cost = ShippingCost.new(
        amount_total: params[:shipping_amount_total] || 500
      )

      # Store for later retrieval
      @@sessions[@id] = self
    end

    def to_hash
      {
        id: @id,
        payment_status: @payment_status,
        client_reference_id: @client_reference_id,
        customer_details: @customer_details.to_hash,
        collected_information: @collected_information.to_hash,
        shipping_cost: { amount_total: @shipping_cost.amount_total }
      }
    end

    def self.create(params)
      @@last_create_params = params
      new(params)
    end

    def self.retrieve(session_id_or_params, params = nil)
      # Support both calling conventions:
      # 1. retrieve(session_id) - simple string
      # 2. retrieve(id: session_id, expand: [...]) - hash with options
      session_id = if session_id_or_params.is_a?(Hash)
        session_id_or_params[:id]
      else
        session_id_or_params
      end

      session = @@sessions[session_id]

      if session.nil?
        error = Stripe::InvalidRequestError.new(
          "No such checkout.session: '#{session_id}'",
          param: "id"
        )
        error.instance_variable_set(:@http_status, 404)
        raise error
      end

      session
    end

    def self.reset!
      @@sessions = {}
      @@next_id = 1
      @@last_create_params = nil
    end

    # Helper to create a session with unpaid status
    def self.create_unpaid(params = {})
      new(params.merge(payment_status: "unpaid"))
    end

    # Helper to create session with custom customer details
    def self.create_with_customer(customer_params)
      new(
        customer_email: customer_params[:email],
        customer_name: customer_params[:name],
        client_reference_id: customer_params[:user_id]
      )
    end

    # Nested class for customer details (billing info)
    class CustomerDetails
      attr_reader :email, :name, :address

      def initialize(email:, name:, address:)
        @email = email
        @name = name
        @address = Address.new(address)
      end

      def to_hash
        {
          email: @email,
          name: @name,
          address: @address.to_hash
        }
      end
    end

    # Nested class for collected_information (Stripe API 2025-03-31+)
    class CollectedInformation
      attr_reader :shipping_details

      def initialize(shipping_details:)
        @shipping_details = shipping_details
      end

      def to_hash
        {
          shipping_details: @shipping_details.to_hash
        }
      end
    end

    # Nested class for shipping details (shipping address)
    class ShippingDetails
      attr_reader :name, :address

      def initialize(name:, address:)
        @name = name
        @address = Address.new(address)
      end

      def to_hash
        {
          name: @name,
          address: @address.to_hash
        }
      end
    end

    # Nested class for address
    class Address
      attr_reader :line1, :line2, :city, :postal_code, :country

      def initialize(params)
        @line1 = params[:line1]
        @line2 = params[:line2]
        @city = params[:city]
        @postal_code = params[:postal_code]
        @country = params[:country]
      end

      def to_hash
        {
          line1: @line1,
          line2: @line2,
          city: @city,
          postal_code: @postal_code,
          country: @country
        }
      end
    end

    # Nested class for shipping cost
    class ShippingCost
      attr_reader :amount_total

      def initialize(amount_total:)
        @amount_total = amount_total
      end
    end
  end

  class TaxRate
    attr_reader :id, :display_name, :percentage, :country,
                :jurisdiction, :description, :inclusive

    @@tax_rates = []
    @@next_id = 1

    def initialize(params = {})
      @id = params[:id] || "txr_test_#{SecureRandom.hex(8)}"
      @display_name = params[:display_name] || "VAT"
      @percentage = params[:percentage]
      @country = params[:country]
      @jurisdiction = params[:jurisdiction]
      @description = params[:description]
      @inclusive = params[:inclusive] || false

      # Store for later retrieval
      @@tax_rates << self
    end

    def self.create(params)
      new(params)
    end

    def self.list(filters = {})
      active = filters[:active]
      limit = filters[:limit] || 100

      results = if active.nil?
        @@tax_rates
      else
        @@tax_rates # In real Stripe, would filter by active status
      end

      ListObject.new(results.take(limit))
    end

    def self.reset!
      @@tax_rates = []
      @@next_id = 1
    end

    # Helper: Create UK VAT rate (20%)
    def self.create_uk_vat
      new(
        display_name: "VAT",
        percentage: 20.0,
        country: "GB",
        jurisdiction: "United Kingdom",
        description: "Value Added Tax",
        inclusive: false
      )
    end

    # Nested class for list responses
    class ListObject
      attr_reader :data

      def initialize(data)
        @data = data
      end
    end
  end

  class PaymentIntent
    attr_reader :id, :status, :amount, :currency, :customer, :payment_method,
                :metadata, :description

    @@payment_intents = {}

    def initialize(params = {})
      @id = params[:id] || "pi_test_#{SecureRandom.hex(12)}"
      @status = params[:status] || "succeeded"
      @amount = params[:amount]
      @currency = params[:currency]
      @customer = params[:customer]
      @payment_method = params[:payment_method]
      @metadata = params[:metadata] || {}
      @description = params[:description]
      @@payment_intents[@id] = self
    end

    def self.create(params = {})
      new(params)
    end

    def self.retrieve(payment_intent_id)
      @@payment_intents[payment_intent_id] || new(id: payment_intent_id)
    end

    def self.reset!
      @@payment_intents = {}
    end
  end

  class Subscription
    attr_reader :id, :status, :pause_collection

    @@subscriptions = {}

    def initialize(params = {})
      @id = params[:id] || "sub_test_#{SecureRandom.hex(12)}"
      @status = params[:status] || "active"
      @pause_collection = params[:pause_collection]
      @@subscriptions[@id] = self
    end

    # Stripe API signature: Stripe::Subscription.update(id, params)
    def self.update(subscription_id, params = {})
      sub = @@subscriptions[subscription_id] || new(id: subscription_id)
      sub.instance_variable_set(:@pause_collection, params[:pause_collection])
      sub
    end

    # Stripe API signature: Stripe::Subscription.cancel(id)
    # DELETE requests are idempotent by definition - no idempotency key needed
    def self.cancel(subscription_id)
      sub = @@subscriptions[subscription_id] || new(id: subscription_id)
      sub.instance_variable_set(:@status, "canceled")
      sub
    end

    def self.retrieve(subscription_id)
      @@subscriptions[subscription_id] || new(id: subscription_id)
    end

    def self.reset!
      @@subscriptions = {}
    end
  end

  class Customer
    attr_reader :id, :email, :name, :shipping, :metadata

    @@customers = {}
    @@last_create_params = nil
    @@last_update_params = nil

    def self.last_create_params
      @@last_create_params
    end

    def self.last_update_params
      @@last_update_params
    end

    def initialize(params = {})
      @id = params[:id] || "cus_test_#{SecureRandom.hex(12)}"
      @email = params[:email]
      @name = params[:name]
      @shipping = params[:shipping]
      @metadata = params[:metadata] || {}
      @@customers[@id] = self
    end

    def self.create(params)
      @@last_create_params = params
      new(params)
    end

    def self.update(customer_id, params = {})
      @@last_update_params = { customer_id: customer_id, params: params }
      customer = @@customers[customer_id]
      if customer
        customer.instance_variable_set(:@email, params[:email]) if params[:email]
        customer.instance_variable_set(:@name, params[:name]) if params[:name]
        customer.instance_variable_set(:@shipping, params[:shipping]) if params[:shipping]
        customer
      else
        new(params.merge(id: customer_id))
      end
    end

    def self.retrieve(customer_id)
      customer = @@customers[customer_id]
      raise Stripe::InvalidRequestError.new("No such customer: '#{customer_id}'", param: "id") unless customer
      customer
    end

    def self.reset!
      @@customers = {}
      @@last_create_params = nil
      @@last_update_params = nil
    end
  end

  # Mock Stripe errors for testing error handling
  module Errors
    def self.card_declined
      error = Stripe::CardError.new(
        "Your card was declined.",
        param: "card",
        code: "card_declined"
      )
      error.instance_variable_set(:@http_status, 402)
      error
    end

    def self.invalid_request(message = "Invalid request")
      error = Stripe::InvalidRequestError.new(message)
      error.instance_variable_set(:@http_status, 400)
      error
    end

    def self.api_connection_error
      Stripe::APIConnectionError.new(
        "Failed to connect to Stripe API"
      )
    end

    def self.api_error
      error = Stripe::APIError.new("An error occurred with our API")
      error.instance_variable_set(:@http_status, 500)
      error
    end
  end
end

# Auto-configure in test environment
if defined?(Rails) && Rails.env.test?
  # Replace Stripe classes with fakes
  module Stripe
    Checkout = Module.new unless defined?(Checkout)
    Checkout::Session = FakeStripe::CheckoutSession
    TaxRate = FakeStripe::TaxRate
    Subscription = FakeStripe::Subscription
    Customer = FakeStripe::Customer
    PaymentIntent = FakeStripe::PaymentIntent

    # Ensure Stripe error classes exist for testing
    class StripeError < StandardError; end
    class CardError < StripeError; end
    class InvalidRequestError < StripeError
      attr_accessor :param
      def initialize(message, param: nil, code: nil)
        super(message)
        @param = param
        @code = code
      end
    end
    class APIConnectionError < StripeError; end
    class APIError < StripeError; end
    class RateLimitError < StripeError; end
  end
end
