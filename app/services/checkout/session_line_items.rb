# frozen_string_literal: true

module Checkout
  # Shared line-item plumbing for a Stripe Checkout Session: identifying the
  # taxed shipping LINE ITEM and fetching the full paginated list. Single home
  # because two money paths depend on the same rule - SessionAmounts subtracts
  # the shipping line to recover the products subtotal, SessionRepricer omits
  # it to replace it - and a divergence between their readings double-charges
  # or drops shipping.
  module SessionLineItems
    # Whether this line item is the shipping line, by the product-metadata flag
    # the session builder stamped on it - never the display name, so a renamed
    # label or a product coincidentally named "Shipping" can't match.
    #
    # A String product means price.product came back as a bare id (the caller
    # dropped the expand); raise so the mistake is caught rather than silently
    # misreading the shipping line as a product. Items with no price at all
    # (e.g. the webhook's bare stubs) are tolerated and simply don't match.
    def self.shipping?(item)
      return false unless item.respond_to?(:price)

      product = item.price&.product
      raise SessionAmounts::UnexpandedLineItemError, "line item product not expanded (id: #{product})" if product.is_a?(String)
      return false unless product.respond_to?(:[])

      # Reference the writer's flag so a rename can't silently desync the two.
      product["metadata"]&.[](Shipping::LINE_ITEM_FLAG_KEY) == Shipping::LINE_ITEM_FLAG_VALUE
    end

    # Every line item of the session (from starting_after onwards, when given),
    # paged in full via the dedicated endpoint with the product expand
    # shipping? depends on. Stripe embeds at most 10 expanded line items in a
    # retrieved session and promises no order, so correctness must never
    # depend on the shipping line landing in the first page.
    def self.list(session_id, starting_after: nil)
      params = { expand: [ "data.price.product" ] }
      params[:starting_after] = starting_after if starting_after
      Stripe::Checkout::Session
        .list_line_items(session_id, **params)
        .auto_paging_each
        .to_a
    end
  end
end
