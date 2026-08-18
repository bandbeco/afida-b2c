# frozen_string_literal: true

module Checkout
  # Reprices an OPEN custom-mode Checkout Session for the destination the
  # customer typed on the on-site checkout page: the taxed shipping line item
  # is rebuilt for the new zone and metadata.shipping_zone is rewritten so the
  # completed order records the zone it was actually charged. The address
  # itself is NOT written here - the Stripe SDK syncs it client-side, exactly
  # as on the hosted page; this service owns only the price.
  #
  # Stripe's line_items update is a full retransmit: a line listed as {id:} is
  # retained, a line with price_data is added, and a line whose id is omitted
  # is removed (verified against the live API; retransmitting the old shipping
  # line's id would RETAIN it and double-charge shipping). Product lines are
  # never touched here - only the shipping line changes hands.
  #
  # The postcode was TYPED by the customer, so an unknown or undeliverable zone
  # raises rather than falling back to mainland the way SessionBuilder prices a
  # destination nobody has stated yet.
  class SessionRepricer
    # shipping_pence is what the customer now pays for delivery (0 when the
    # order ships free), so the endpoint can echo the new charge without
    # re-deriving the free-shipping rule.
    Result = Struct.new(:zone, :session, :shipping_pence, keyword_init: true)

    class UndeliverableZone < StandardError
      attr_reader :zone

      def initialize(zone)
        @zone = zone
        super("cannot deliver to zone #{zone}")
      end
    end

    # The delivery charge for this cart to this zone, in pence. Mirrors
    # SessionBuilder#shipping_line_item's rule (and OrderTotals'): free
    # delivery is a mainland promise gated on the products subtotal. Public so
    # the reprice endpoint can quote a zone it did not need to reprice (the
    # same-zone short-circuit).
    def self.shipping_pence(zone:, cart:)
      free = ShippingZone.free_shipping?(zone) && cart.subtotal_amount >= Shipping::FREE_SHIPPING_THRESHOLD
      free ? 0 : Shipping.cost_for_zone(zone)
    end

    def initialize(stripe_session_id:, cart:, postcode:)
      @stripe_session_id = stripe_session_id
      @cart = cart
      @postcode = postcode
    end

    def call
      zone = ShippingZone.for(postcode)
      raise UndeliverableZone, zone unless ShippingZone.deliverable?(zone)

      session = Stripe::Checkout::Session.update(stripe_session_id, {
        line_items: rebuilt_line_items(zone),
        metadata: { shipping_zone: zone.to_s }
      })

      Result.new(
        zone: zone,
        session: session,
        shipping_pence: self.class.shipping_pence(zone: zone, cart: cart)
      )
    end

    private

    attr_reader :stripe_session_id, :cart, :postcode

    # The new shipping line (unless the order now ships free), then every
    # product line retained untouched by id. Prepending keeps the shipping line
    # inside Stripe's first embedded page of line items, the same best-effort
    # optimisation SessionBuilder makes for SessionAmounts.
    def rebuilt_line_items(zone)
      items = product_lines.map { |line| { id: line.id } }
      items.unshift(shipping_line(zone)) unless self.class.shipping_pence(zone: zone, cart: cart).zero?
      items
    end

    def shipping_line(zone)
      Shipping.shipping_line_item(tax_rate_id: tax_rate.id, zone: zone)
    end

    def product_lines
      current_line_items.reject { |item| shipping_line?(item) }
    end

    # All line items on the session, paged in full: the shipping line is
    # prepended at creation but Stripe does not promise an order, so correctness
    # must not depend on it landing in the first page.
    def current_line_items
      Stripe::Checkout::Session
        .list_line_items(stripe_session_id, expand: [ "data.price.product" ])
        .auto_paging_each
        .to_a
    end

    # Same identification rule as SessionAmounts: the flag the session builder
    # stamped on the shipping line's product metadata, never the display name.
    def shipping_line?(item)
      product = item.price&.product
      return false unless product.respond_to?(:[])

      product["metadata"]&.[](Shipping::LINE_ITEM_FLAG_KEY) == Shipping::LINE_ITEM_FLAG_VALUE
    end

    def tax_rate
      @tax_rate ||= StripeTaxRateProvider.new.tax_rate
    end
  end
end
