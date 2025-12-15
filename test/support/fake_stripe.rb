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
  end

  # Configure default behavior
  def self.configure
    yield self
  end

  class CheckoutSession
    attr_reader :id, :url, :payment_status, :customer_details,
                :shipping_cost, :client_reference_id, :line_items

    @@sessions = {}
    @@next_id = 1
    @@pending_line_items = nil  # Cart items captured at create time

    def initialize(params = {})
      @id = "sess_test_#{SecureRandom.hex(12)}"
      @url = "https://checkout.stripe.com/test/#{@id}"
      @payment_status = params[:payment_status] || "paid"
      @client_reference_id = params[:client_reference_id]

      # Build customer details from params or use defaults
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

      # Default shipping cost (£5.00 = 500 pence)
      @shipping_cost = ShippingCost.new(
        amount_total: params[:shipping_amount_total] || 500
      )

      # Build line_items from the params (what was passed to Stripe at checkout)
      # or use pending_line_items if set
      @line_items = build_line_items(params[:line_items] || @@pending_line_items || [])
      @@pending_line_items = nil

      # Store for later retrieval
      @@sessions[@id] = self
    end

    def self.create(params)
      # Capture line_items at create time (simulates Stripe storing what was charged)
      @@pending_line_items = params[:line_items]
      new(params)
    end

    def self.retrieve(session_id_or_params)
      # Support both old-style (just ID) and new-style (hash with id and expand)
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
      @@pending_line_items = nil
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

    private

    # Build line_items structure that mirrors Stripe's expanded response
    def build_line_items(raw_line_items)
      return LineItemsCollection.new([]) if raw_line_items.nil? || raw_line_items.empty?

      items = raw_line_items.map do |item|
        price_data = item[:price_data] || {}
        product_data = price_data[:product_data] || {}
        unit_amount = price_data[:unit_amount] || 0
        quantity = item[:quantity] || 1

        LineItem.new(
          description: product_data[:name] || "Unknown Product",
          quantity: quantity,
          amount_subtotal: unit_amount * quantity,
          amount_tax: ((unit_amount * quantity) * 0.2).to_i,  # 20% VAT
          amount_total: (unit_amount * quantity * 1.2).to_i,
          price: Price.new(
            unit_amount: unit_amount,
            product: Product.new(
              metadata: product_data[:metadata] || {}
            )
          )
        )
      end

      LineItemsCollection.new(items)
    end

    public

    # Nested class for line items collection (supports .data accessor)
    class LineItemsCollection
      attr_reader :data

      def initialize(items)
        @data = items
      end
    end

    # Nested class for line item
    class LineItem
      attr_reader :description, :quantity, :amount_subtotal, :amount_tax, :amount_total, :price

      def initialize(description:, quantity:, amount_subtotal:, amount_tax:, amount_total:, price:)
        @description = description
        @quantity = quantity
        @amount_subtotal = amount_subtotal
        @amount_tax = amount_tax
        @amount_total = amount_total
        @price = price
      end
    end

    # Nested class for price
    class Price
      attr_reader :unit_amount, :product

      def initialize(unit_amount:, product:)
        @unit_amount = unit_amount
        @product = product
      end
    end

    # Nested class for product (with metadata)
    # Stripe returns metadata with string keys, so we convert symbol keys
    class Product
      attr_reader :metadata

      def initialize(metadata:)
        # Convert symbol keys to string keys to match real Stripe behavior
        @metadata = (metadata || {}).transform_keys(&:to_s)
      end
    end

    # Nested class for customer details
    class CustomerDetails
      attr_reader :email, :name, :address

      def initialize(email:, name:, address:)
        @email = email
        @name = name
        @address = Address.new(address)
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

    def self.retrieve(tax_rate_id)
      rate = @@tax_rates.find { |r| r.id == tax_rate_id }

      if rate.nil?
        # Return a default UK VAT rate if not found (simulates cached credential lookup)
        new(
          id: tax_rate_id,
          display_name: "VAT",
          percentage: 20.0,
          country: "GB",
          jurisdiction: "United Kingdom",
          description: "Value Added Tax",
          inclusive: false
        )
      else
        rate
      end
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

  class Customer
    attr_reader :id, :email, :name, :metadata

    @@customers = {}
    @@idempotency_keys = {}

    def initialize(params = {})
      # Generate ID matching Stripe's format: cus_ + alphanumeric (no underscores)
      @id = params[:id] || "cus_#{SecureRandom.alphanumeric(24)}"
      @email = params[:email]
      @name = params[:name]
      @metadata = params[:metadata] || {}
      @@customers[@id] = self
    end

    # Supports idempotency key as second argument (Stripe SDK pattern)
    def self.create(params, options = {})
      idempotency_key = options[:idempotency_key]

      # If idempotency key provided and already used, return cached customer
      if idempotency_key && @@idempotency_keys[idempotency_key]
        return @@idempotency_keys[idempotency_key]
      end

      customer = new(params)

      # Cache by idempotency key if provided
      if idempotency_key
        @@idempotency_keys[idempotency_key] = customer
      end

      customer
    end

    def self.retrieve(customer_id)
      @@customers[customer_id] || new(id: customer_id)
    end

    def self.reset!
      @@customers = {}
      @@idempotency_keys = {}
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
  end
end
