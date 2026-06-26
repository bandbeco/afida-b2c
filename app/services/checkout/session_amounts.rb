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
  # own amount_subtotal. Both figures are PRE-discount (verified against the live
  # API: amount_total = amount_subtotal + amount_tax - amount_discount), so the
  # split yields the gross products subtotal and gross shipping, with the discount
  # carried separately. amount_tax already spans products + shipping.
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
    # Raised when a line item carries a price but its product is unexpanded (a
    # String id), which means the caller forgot expand: line_items.data.price.product.
    # Without the expanded product the shipping line cannot be identified, so we
    # fail loud rather than silently recording £0 shipping and an inflated subtotal.
    class UnexpandedLineItemError < StandardError; end

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
    #
    # A String product means price.product was returned as a bare id (the caller
    # omitted the nested expand); raise so the missing expand is caught rather than
    # silently treating the shipping line as a product. Items with no price at all
    # (e.g. the webhook's bare stubs) are tolerated and simply don't match.
    def shipping_line?(item)
      return false unless item.respond_to?(:price)

      product = item.price&.product
      raise UnexpandedLineItemError, "line item product not expanded (id: #{product})" if product.is_a?(String)
      return false unless product.respond_to?(:[])

      # Reference the writer's flag so a rename can't silently desync the two.
      product["metadata"]&.[](Shipping::LINE_ITEM_FLAG_KEY) == Shipping::LINE_ITEM_FLAG_VALUE
    end

    def legacy_shipping_cost
      (@session.shipping_cost&.amount_total || 0).to_i
    end

    # All line items for the session. Stripe returns at most 10 expanded line
    # items in the embedded list and does not promise an order, so when the list
    # reports has_more we page through every line item via the dedicated endpoint
    # (retrieve does not auto-paginate). Otherwise the shipping line can sit on a
    # later page and be missed, recording shipping as £0. The embedded first page
    # is used as-is when it is complete, so the common case makes no extra call.
    def line_items
      return @line_items if defined?(@line_items)

      embedded = @session.line_items
      page_one = embedded&.data || []
      @line_items =
        if embedded.respond_to?(:has_more) && embedded.has_more
          page_one + line_items_after(page_one.last)
        else
          page_one
        end
    end

    # The line items after the embedded first page, fetched via the dedicated
    # endpoint (retrieve does not auto-paginate). starting_after avoids re-fetching
    # the page Stripe already returned. If the embedded page was empty (has_more true
    # but no data, a defensive edge), there is no boundary item, so list from the
    # start instead of dereferencing nil. A Stripe error propagates to the caller's
    # handler rather than being treated as "no shipping line".
    def line_items_after(last_embedded_item)
      params = { expand: [ "data.price.product" ] }
      params[:starting_after] = last_embedded_item.id if last_embedded_item
      Stripe::Checkout::Session
        .list_line_items(@session.id, **params)
        .auto_paging_each
        .to_a
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
