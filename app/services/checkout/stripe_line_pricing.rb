# frozen_string_literal: true

module Checkout
  # Stripe quantity and unit amount (pence) for one cart item.
  #
  # SessionBuilder sends these figures on the Checkout line item, and
  # OrderCreator compares the paid session against the cart with the same
  # figures, so the two cannot drift.
  #
  # Pack counts and configured unit counts are not Stripe quantities. Those
  # items are one line (quantity 1) whose unit_amount is
  # round(price * quantity * 100): cart_items.price is decimal(10,4), and
  # rounding each line once is what keeps Stripe's subtotal exact. Rounding
  # the whole cart once can disagree by a penny. Samples are quantity 1 at 0.
  # Unit-priced items (pac_size blank or 0) keep their quantity and a
  # per-unit amount.
  class StripeLinePricing
    def self.for(cart_item)
      new(cart_item)
    end

    def initialize(cart_item)
      @cart_item = cart_item
    end

    def quantity
      return 1 if cart_item.sample? || cart_item.configured?
      return cart_item.quantity if unit_priced?

      # Pack-priced items fold pack count into unit_amount for one Stripe subtotal.
      1
    end

    def unit_amount
      if cart_item.sample?
        0
      elsif cart_item.configured?
        (cart_item.price.to_f * cart_item.quantity * 100).round
      elsif unit_priced?
        (cart_item.price.to_f * 100).round
      else
        # Pack-priced items use one Stripe line item with the pack count folded
        # into unit_amount, so Stripe's tax/discount math sees one subtotal.
        (cart_item.price.to_f * cart_item.quantity * 100).round
      end
    end

    # Pence Stripe stores as the line's pre-discount amount_subtotal
    # (quantity * unit_amount, with the rounding already inside unit_amount).
    def amount_pence
      quantity * unit_amount
    end

    def unit_priced?
      cart_item.product.pac_size.blank? || cart_item.product.pac_size.zero?
    end

    private

    attr_reader :cart_item
  end
end
