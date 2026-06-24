# frozen_string_literal: true

module Checkout
  # Derives the money figures we persist on an Order from a completed Stripe
  # Checkout session, in pounds. Single home for "given an expanded session, what
  # are the subtotal / vat / shipping / total / discount" so the success path
  # (OrderCreator) and the webhook fallback compute them identically.
  #
  # Why this exists: shipping is sent as a taxed LINE ITEM (manual tax rates do
  # not tax shipping_options), so Stripe's amount_subtotal now INCLUDES shipping
  # and shipping_cost is no longer populated. To recover the products-only
  # subtotal we locate the shipping line by its product metadata and subtract its
  # own post-discount amount_subtotal; reading each line's own figure is what
  # makes whole-order and product-only discounts reconcile without us
  # re-allocating the discount. amount_tax already spans products + shipping.
  #
  # Callers must expand the session with "line_items.data.price.product" so the
  # metadata is present; without it the shipping line cannot be identified.
  #
  # Legacy fallback: sessions created before line-item shipping have a populated
  # shipping_cost and no shipping line item, and their amount_subtotal excludes
  # shipping. Those still record the shipping the customer was charged rather than
  # dropping it to zero. Safe to remove once such sessions can no longer complete
  # (after the Stripe Checkout session expiry window).
  Amounts = Data.define(:subtotal, :vat, :shipping, :total, :discount)

  class SessionAmounts
    SHIPPING_LINE_FLAG = "shipping_line"

    def self.from(session)
      new(session).amounts
    end

    def initialize(session)
      @session = session
    end

    def amounts
      shipping_pence, products_offset = shipping_breakdown
      Amounts.new(
        subtotal: pounds(amount_subtotal - products_offset),
        vat: pounds(amount_tax),
        shipping: pounds(shipping_pence),
        total: pounds(@session.amount_total),
        discount: pounds(amount_discount)
      )
    end

    private

    # Returns [shipping_pence, products_offset]. products_offset is the amount to
    # subtract from amount_subtotal to get the products-only subtotal: the
    # shipping line's own subtotal when shipping is a line item (because
    # amount_subtotal includes it), or 0 for the legacy shipping_cost path (where
    # amount_subtotal already excludes shipping).
    def shipping_breakdown
      line = shipping_line_item
      return [ line.amount_subtotal, line.amount_subtotal ] if line

      legacy = legacy_shipping_cost
      return [ legacy, 0 ] if legacy.positive?

      [ 0, 0 ]
    end

    def shipping_line_item
      line_items.find { |item| shipping_line?(item) }
    end

    # The shipping line is identified by its expanded product metadata, set when
    # the session is built, so a renamed display label or a product coincidentally
    # named "Shipping" never matches.
    def shipping_line?(item)
      product = item.price&.product if item.respond_to?(:price)
      return false unless product.respond_to?(:[])

      product["metadata"]&.[](SHIPPING_LINE_FLAG) == "true"
    end

    def legacy_shipping_cost
      (@session.shipping_cost&.amount_total || 0).to_i
    end

    def line_items
      @session.line_items&.data || []
    end

    def amount_subtotal
      @session.amount_subtotal.to_i
    end

    def amount_tax
      (@session.total_details&.amount_tax || 0).to_i
    end

    def amount_discount
      (@session.total_details&.amount_discount || 0).to_i
    end

    def pounds(pence)
      pence / 100.0
    end
  end
end
