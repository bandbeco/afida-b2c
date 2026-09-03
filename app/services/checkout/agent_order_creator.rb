module Checkout
  # Builds a paid Order from a Checkout Session completed by an AI agent
  # through Stripe Agentic Commerce. Parallel to OrderCreator, which builds
  # from a website cart: an agent checkout has no cart, so the items come
  # from the session's line items, matched back to Products by the catalogue
  # SKU the product feed sent as each price's external_reference.
  #
  # Money is read straight off the session. Unlike website sessions, shipping
  # is a shipping_option (set by the checkout customization hook), so
  # amount_subtotal is products-only and delivery sits in
  # total_details.amount_shipping; SessionAmounts' shipping-line split does
  # not apply.
  #
  # Callers retrieve the session with expand: ["line_items.data.price.product",
  # "collected_information"] so the SKU and addresses are present.
  class AgentOrderCreator
    # The payment has been taken for a SKU we do not sell. Permanent: retrying
    # the webhook cannot make the product appear, so the caller must alert ops
    # rather than let Stripe retry.
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
        # shipping_zone is left for Order#set_shipping_zone to derive from the
        # delivered-to postcode: an agent session carries no priced-zone
        # metadata, and the hook priced it from this same address.
      }
    end

    # Resolved before the transaction opens so an unknown SKU raises with
    # nothing written.
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

    # payment_intent.agent_details is a private-preview field; read it only
    # when the expanded intent exposes it.
    def agent_name
      details = stripe_session.try(:payment_intent).try(:agent_details)
      details.try(:name) || details.try(:[], "name")
    end

    def pounds(pence)
      pence.to_i / 100.0
    end
  end
end
