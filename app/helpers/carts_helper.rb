module CartsHelper
  # Single source of truth for the first-order ("welcome") discount.
  #
  # The actual money is taken by a Stripe coupon (see
  # EmailSubscriptionsController#welcome_discount_code); this percentage only
  # drives the on-site copy and the "you'll save £X" estimate. Keep the two in
  # sync: if you change this, point the Stripe coupon at the same percentage.
  WELCOME_DISCOUNT_PERCENTAGE = 10

  # The discount as a whole number for copy, e.g. "Get 10% off".
  def welcome_discount_percentage
    WELCOME_DISCOUNT_PERCENTAGE
  end

  # The cart-totals summary as an ordered list of display lines, the single source
  # of truth shared by the cart page and the cart drawer (the cart-side twin of
  # order_summary_lines). Delegates to CartSummary so the line order, labels, money
  # format and discount-visibility rule live in one place; each surface supplies its
  # own row markup. See CartSummary for the shape of each line.
  def cart_summary_lines(cart)
    CartSummary.lines(cart)
  end

  # The DOM id for a cart-summary line's amount span on the cart page, kept stable
  # across the names earlier markup used. The Total uses "grand_total" (handled in
  # the partial); the discount amount keeps "discount_amount".
  def cart_summary_line_dom_id(kind)
    kind == :discount ? "discount_amount" : kind.to_s
  end

  # The saving shown in the "you'll save £X" copy. The welcome coupon is a whole-order
  # Stripe percent_off (subtotal + shipping), so the saving is the cart's own
  # discount_amount, computed once by OrderTotals. Callers show this only when the
  # discount is active (the rate is injected), so discount_amount is the real figure
  # and the success-box copy stays in lockstep with the cart-summary discount line.
  def welcome_discount_savings(cart)
    cart.discount_amount
  end

  # Determine if the discount signup form should be shown
  #
  # Returns true if:
  # - User is not logged in (guest), OR
  # - User is logged in but has no previous orders
  #
  # Returns false if:
  # - User is logged in AND has previous orders
  # - Discount code is already in session
  #
  # @return [Boolean]
  def show_discount_signup?
    # Don't show if discount already claimed in this session
    return false if session[:discount_code].present?

    # Show for guests
    return true unless Current.user

    # Show for logged-in users without orders
    !Current.user.orders.exists?
  end
end
