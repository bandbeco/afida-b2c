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

  # The discount as a fraction for arithmetic, e.g. subtotal * 0.10.
  def welcome_discount_rate
    WELCOME_DISCOUNT_PERCENTAGE / 100.0
  end

  # The saving shown in the "you'll save £X" copy. The welcome coupon is a whole-order
  # Stripe percent_off (subtotal + shipping), so the saving is the cart's own
  # discount_amount, computed once by OrderTotals. Callers show this only when the
  # discount is active (the rate is injected), so discount_amount is the real figure
  # and the success-box copy stays in lockstep with the cart-summary discount line.
  def welcome_discount_savings(cart)
    cart.discount_amount
  end

  # The cart preview's shipping line. The cart charges shipping the same way
  # checkout does, so this shows "Free" at/above the free-shipping threshold, the
  # currency amount below it, and "Calculate at checkout" only for an empty cart
  # (shipping_amount is nil) which never actually renders the summary.
  def cart_shipping_display(cart)
    shipping = cart.shipping_amount
    return "Calculate at checkout" if shipping.nil?

    shipping.zero? ? "Free" : number_to_currency(shipping)
  end

  # Whether the cart carries a discount worth showing a line for. Guards the
  # discount row so it appears only when a coupon is actually reducing the total.
  def cart_has_discount?(cart)
    cart.discount_amount.positive?
  end

  # The cart preview's discount line: the discount as a negative currency amount,
  # e.g. "-£2.00". Shown between Subtotal and Shipping when cart_has_discount?.
  def cart_discount_display(cart)
    "-#{number_to_currency(cart.discount_amount, unit: '£')}"
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
