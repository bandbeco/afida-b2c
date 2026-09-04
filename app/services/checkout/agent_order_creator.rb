module Checkout
  class AgentOrderCreator
    class UnknownSkuError < StandardError; end

    SOURCE = "agent"

    def initialize(stripe_session:)
      @stripe_session = stripe_session
    end

    def create
      shipping_address = Checkout::SessionDetails.shipping_address(stripe_session)
      if Order.required_shipping_values(shipping_address).any?(&:blank?)
        raise Checkout::MissingShippingDetails, "Shipping details are required"
      end

      items = order_items_attributes

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
        email: stripe_session.customer_details.email,
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
      line_items.map do |line_item|
        sku = line_item.price.external_reference
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

    def line_items
      stripe_session.line_items&.data || []
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
