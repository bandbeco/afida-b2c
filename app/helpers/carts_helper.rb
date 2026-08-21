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

  # The minimum order the welcome discount requires, as copy (e.g. "£100").
  #
  # Stripe is what actually enforces this: restrictions.minimum_amount on the
  # WELCOME10 promotion code. The figure is read from the shared threshold
  # constant so the on-site copy cannot drift from the Stripe restriction or
  # from the free-delivery message that quotes the same number. If the Stripe
  # restriction changes, change FREE_SHIPPING_THRESHOLD (or split the two apart
  # deliberately) rather than editing the views.
  def welcome_discount_minimum
    Shipping.formatted_free_shipping_threshold
  end

  # The one-line condition shown wherever the discount is offered, so the offer
  # is never stated without its qualifier.
  def welcome_discount_terms
    "On first orders over #{welcome_discount_minimum}."
  end

  # Whether this cart currently clears the minimum.
  #
  # Compares the PRODUCTS subtotal, matching Shipping.free_shipping?. Stripe
  # evaluates its own minimum against the session total (shipping included), so
  # a cart just under the threshold that pays delivery can satisfy Stripe while
  # this returns false. That direction is deliberate: it under-promises on site
  # and the customer gets the discount anyway, which is far better than the
  # reverse.
  def welcome_discount_qualifies?(cart)
    return false unless cart

    cart.subtotal_amount >= Shipping::FREE_SHIPPING_THRESHOLD
  end

  # How much more is needed to unlock the discount; zero once qualified.
  def welcome_discount_shortfall(cart)
    return Shipping::FREE_SHIPPING_THRESHOLD unless cart

    remaining = Shipping::FREE_SHIPPING_THRESHOLD - cart.subtotal_amount
    remaining.positive? ? remaining : 0
  end

  # The cart-totals summary as an ordered list of display lines, the single source
  # of truth shared by the cart page and the cart drawer (the cart-side twin of
  # order_summary_lines). Delegates to CartSummary so the line order, labels, money
  # format and discount-visibility rule live in one place; each surface supplies its
  # own row markup. See CartSummary for the shape of each line.
  def cart_summary_lines(cart, placeholder_discount: false)
    CartSummary.lines(cart, placeholder_discount: placeholder_discount)
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
