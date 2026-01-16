module CartsHelper
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
