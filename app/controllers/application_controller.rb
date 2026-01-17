class ApplicationController < ActionController::Base
  include Authentication
  include EventContext
  before_action :set_current_cart
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  if Rails.env.production?
    allow_browser versions: :modern
  end

  private

  def set_current_cart
    # If the user is logged in, find or create a cart for them
    if Current.user
      Current.cart = Cart.find_or_create_by(user: Current.user)
    elsif session[:cart_id]
      # If the user is not logged in, but there is a cart_id in session, find the cart
      cart = Cart.find_by(id: session[:cart_id])
      if cart&.guest_cart?
        Current.cart = cart
      else
        # If the cart_id in session belongs to a user, or doesn't exist, or was claimed, clear the session and create a new guest cart
        session.delete(:cart_id)
        Current.cart = Cart.create
        session[:cart_id] = Current.cart.id if Current.cart&.persisted?
      end
    else
      # If the user is not logged in, and there is no cart_id in session, create a new guest cart
      Current.cart = Cart.create
      session[:cart_id] = Current.cart.id if Current.cart&.persisted?
    end
  end
end
