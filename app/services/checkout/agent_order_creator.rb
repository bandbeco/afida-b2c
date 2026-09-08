module Checkout
  class AgentOrderCreator
    class SessionNotBuildableError < StandardError; end
    class UnknownSkuError < SessionNotBuildableError; end
    class EmptyOrderError < SessionNotBuildableError; end

    SOURCE = "agent"

    def initialize(stripe_session:)
      @stripe_session = stripe_session
    end

    def agent_session?
      catalogue_line_items.any?
    end

    def create
      shipping_address = Checkout::SessionDetails.shipping_address(stripe_session)
      if Order.required_shipping_values(shipping_address).any?(&:blank?)
        raise Checkout::MissingShippingDetails, "Shipping details are required"
      end

      items = order_items_attributes
      raise EmptyOrderError, "no catalogue line items on session #{stripe_session.id}" if items.empty?

      ApplicationRecord.transaction do
        order = Order.create!(order_attributes)
        items.each { |attributes| order.order_items.create!(attributes) }
        order
      end
    end

    private

    attr_reader :stripe_session

    def order_attributes
      {
        email: stripe_session.customer_details&.email,
        stripe_session_id: stripe_session.id,
        status: "paid",
        source: SOURCE,
        agent_name: agent_name,
        subtotal_amount: pounds(stripe_session.amount_subtotal),
        vat_amount: pounds(total_details&.amount_tax),
        shipping_amount: pounds(total_details&.amount_shipping),
        total_amount: pounds(stripe_session.amount_total),
        discount_amount: pounds(total_details&.amount_discount),
        **Checkout::SessionDetails.order_address_attributes(stripe_session)
      }
    end

    def order_items_attributes
      catalogue_line_items.map do |line_item|
        sku = catalogue_sku(line_item)
        product = Product.find_by(sku: sku)
        raise UnknownSkuError, "no product with SKU #{sku.inspect} on session #{stripe_session.id}" unless product

        {
          product: product,
          product_name: product.generated_title,
          product_sku: product.sku,
          quantity: line_item.quantity,
          price: pounds(line_item.price.unit_amount),
          pac_size: product.pac_size,
          line_total: pounds(line_item.amount_subtotal)
        }
      end
    end

    # The catalogue SKU the feed put on the price, or nil for any other line the
    # agent checkout added (delivery, fees): those are charges, not products.
    def catalogue_sku(line_item)
      line_item.try(:price).try(:external_reference).presence
    end

    def catalogue_line_items
      @catalogue_line_items ||= line_items.select { |item| catalogue_sku(item) }
    end

    def line_items
      SessionLineItems.all(stripe_session, stripe_version: AgenticCommerce::CHECKOUT_API_VERSION)
    end

    def total_details
      stripe_session.total_details
    end

    def agent_name
      details = stripe_session.try(:payment_intent).try(:agent_details)
      details.try(:name) || details.try(:[], "name")
    end

    def pounds(pence)
      pence.to_i / 100.0
    end
  end
end
