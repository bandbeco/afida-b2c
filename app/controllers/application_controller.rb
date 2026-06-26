class ApplicationController < ActionController::Base
  include Authentication
  include EventContext
  before_action :set_current_cart
  before_action :set_nav_categories
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  if Rails.env.production?
    allow_browser versions: :modern
  end

  private

  def set_nav_categories
    @nav_categories = Category.browsable.top_level.order(:position)
    @nav_subcategories_by_parent = Category.subcategories
                                           .where(parent_id: @nav_categories.select(:id))
                                           .includes(:parent)
                                           .order(:position)
                                           .group_by(&:parent_id)
    @nav_vegware_collection = Collection.regular.find_by(slug: Collection::VEGWARE_SLUG)
    @nav_vegware_categories = if @nav_vegware_collection
      Category.browsable.top_level
              .where(id: @nav_vegware_collection.products.joins(:category).select("categories.parent_id"))
              .order(:position)
    else
      []
    end
  end

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

    apply_session_discount_to_cart
  end

  # The welcome coupon code is held in the session; inject its rate onto the cart so
  # the cart preview's discount line, VAT and total match what Stripe will charge.
  # No code means no discount (the rate defaults to zero on the cart).
  def apply_session_discount_to_cart
    return unless Current.cart && session[:discount_code].present?

    Current.cart.discount_rate = CartsHelper::WELCOME_DISCOUNT_PERCENTAGE / 100.0
  end
end
