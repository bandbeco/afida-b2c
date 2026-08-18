# frozen_string_literal: true

module Checkout
  # Reprices an OPEN custom-mode Checkout Session for the destination the
  # customer typed on the on-site checkout page, in one Stripe update: the
  # shipping line item is rebuilt for the new zone, the typed address is
  # recorded as the session's collected shipping details (the session is
  # created with permissions.update_shipping_details=server_only, so this is
  # the only way the address reaches Stripe), and metadata.shipping_zone is
  # rewritten so the completed order records the zone it was actually charged.
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

    # priced_zone is the zone the session's line items were last built for (the
    # controller's stash). When the typed postcode resolves to that same zone
    # the shipping line is already right, so the rebuild (and its line-item
    # listing round-trip) is skipped - but the update itself still happens:
    # under server_only the client cannot sync the address, so this call is the
    # only way the typed shipping details ever reach the session.
    def initialize(stripe_session_id:, cart:, postcode:, shipping_details:, priced_zone: nil)
      @stripe_session_id = stripe_session_id
      @cart = cart
      @postcode = postcode
      @shipping_details = shipping_details
      @priced_zone = priced_zone
    end

    def call
      zone = ShippingZone.for(postcode)
      raise UndeliverableZone, zone unless ShippingZone.deliverable?(zone)

      params = {
        collected_information: { shipping_details: shipping_details },
        metadata: { shipping_zone: zone.to_s }
      }
      params[:line_items] = rebuilt_line_items(zone) unless zone.to_s == priced_zone.to_s

      session = Stripe::Checkout::Session.update(stripe_session_id, params)

      Result.new(
        zone: zone,
        session: session,
        shipping_pence: free_shipping?(zone) ? 0 : Shipping.cost_for_zone(zone)
      )
    end

    private

    attr_reader :stripe_session_id, :cart, :postcode, :shipping_details, :priced_zone

    # The new shipping line (unless the order now ships free), then every
    # product line retained untouched by id. Prepending keeps the shipping line
    # inside Stripe's first embedded page of line items, the same best-effort
    # optimisation SessionBuilder makes for SessionAmounts.
    def rebuilt_line_items(zone)
      items = product_lines.map { |line| { id: line.id } }
      items.unshift(shipping_line(zone)) unless free_shipping?(zone)
      items
    end

    # Mirrors SessionBuilder#shipping_line_item's rule (and OrderTotals'): free
    # delivery is a mainland promise gated on the products subtotal. The CART
    # subtotal is authoritative here, not Stripe's line amounts - the controller
    # has already fingerprint-checked that the cart still matches the session.
    def free_shipping?(zone)
      ShippingZone.free_shipping?(zone) && cart.subtotal_amount >= Shipping::FREE_SHIPPING_THRESHOLD
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
