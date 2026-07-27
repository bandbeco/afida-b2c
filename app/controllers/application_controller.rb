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

  # 301 to a canonical path, carrying the raw query string through unchanged
  # (same semantics as the redirect blocks in config/routes.rb; avoids the
  # re-ordering that Hash#to_query would introduce).
  def redirect_permanently_preserving_query(path)
    path += "?#{request.query_string}" if request.query_string.present?
    redirect_to path, status: :moved_permanently
  end

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
    apply_session_delivery_postcode_to_cart
  end

  # The welcome coupon code is held in the session; inject its rate onto the cart so
  # the cart preview's discount line, VAT and total match what Stripe will charge.
  # No code means no discount (the rate defaults to zero on the cart).
  def apply_session_discount_to_cart
    return unless Current.cart && session[:discount_code].present?

    Current.cart.discount_rate = CartsHelper::WELCOME_DISCOUNT_PERCENTAGE / 100.0
  end

  # The delivery postcode the customer entered on the cart page lives in the
  # session, so every cart surface (page, drawer, Turbo Stream updates) prices the
  # same destination. Without it the cart would quote mainland shipping and the
  # customer would meet the surcharge for the first time at the payment screen.
  #
  # A logged-in customer's default address is the fallback. Without it the cart
  # would defer pricing entirely for a customer who has already told us where
  # they ship, and they'd meet the charge for the first time at the payment
  # screen. A typed postcode still wins, since it is the more recent explicit
  # choice.
  #
  # CheckoutsController#delivery_postcode_for resolves in exactly this order and
  # must keep doing so: when it preferred a selected saved address instead, a
  # customer could be quoted £6.99 on the cart and charged £25 by Stripe.
  def apply_session_delivery_postcode_to_cart
    return unless Current.cart

    postcode = session[:delivery_postcode].presence || default_address_postcode
    return if postcode.blank?

    Current.cart.delivery_postcode = postcode
  end

  # Checks the cart's owner first and Current.user second: pages that call
  # allow_unauthenticated_access skip resume_session (so Current.user is nil
  # there), while a signed-in customer can still hold a guest cart (set_current_cart
  # only binds a user cart when Current.user is set). Taking either keeps every
  # surface pricing the same destination.
  #
  # Memoized per request: this runs from the set_current_cart before_action on
  # every authenticated page load, and again from the view helper and the
  # checkout guard, which would otherwise repeat the same indexed lookup. The
  # ivar is defined? -guarded so a nil result is cached too.
  def default_address_postcode
    return @default_address_postcode if defined?(@default_address_postcode)

    owner = Current.cart&.user || Current.user
    @default_address_postcode = owner&.addresses&.default_first&.first&.postcode
  end
end
