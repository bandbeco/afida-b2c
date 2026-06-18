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

  # Estimated saving on a cart's subtotal at the welcome rate. The real discount
  # is computed by Stripe at checkout; this is the indicative figure we show.
  def welcome_discount_savings(cart)
    cart.subtotal_amount * welcome_discount_rate
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
