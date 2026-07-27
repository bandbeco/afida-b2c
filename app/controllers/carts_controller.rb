class CartsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session  # Resume session to check if user is logged in (for address modal)
  before_action :eager_load_cart, only: :show

  def show
    @cart_items = Current.cart.cart_items
      .includes(:product)
      .order("products.name ASC")

    Rails.event.notify("cart.viewed",
      cart_id: Current.cart.id,
      item_count: Current.cart.items_count,
      subtotal: Current.cart.subtotal_amount.to_f
    )
  end

  # GET /cart/resume?token=...
  # Restores an abandoned cart from a signed recovery link (e.g. a Klaviyo
  # abandoned-cart email) by re-binding the visitor's session to it, then shows
  # the cart. Only guest carts are re-bound: a user-owned cart belongs to an
  # account and is loaded via Current.user, so we never let a link hijack it.
  # An invalid/expired/missing token simply falls through to the session's own
  # cart, so a bad link never errors or leaks another cart.
  def resume
    cart = Cart.find_by_recovery_token(params[:token])
    session[:cart_id] = cart.id if cart&.guest_cart?

    redirect_to cart_path
  end

  # POST /cart/delivery_postcode
  # The cart-page "calculate delivery" field. Stores the postcode in the session
  # so every cart surface prices the same destination and the checkout POST knows
  # where the order is going: line-item prices are fixed when the Stripe session
  # is built, one screen before Stripe collects the address.
  #
  # A blank submission clears it (back to deferred pricing). Anything we can't
  # price is refused AND clears whatever was stored before, so a customer is
  # never shown a price for a destination they have just replaced.
  #
  # The two refusal reasons get different messages because they are different
  # problems: a typo is worth retrying, whereas JE2 3AB is a perfectly valid
  # postcode we simply do not deliver to, and telling that customer we didn't
  # recognise it would send them round a loop that cannot succeed.
  def delivery_postcode
    postcode = params[:delivery_postcode].to_s.strip
    zone = ShippingZone.for(postcode)

    if postcode.blank?
      session.delete(:delivery_postcode)
    elsif ShippingZone.deliverable?(zone)
      session[:delivery_postcode] = postcode
    else
      session.delete(:delivery_postcode)
      flash[:alert] = delivery_postcode_error(zone)
    end

    redirect_to cart_path
  end

  def destroy
    @cart.destroy
    redirect_to root_path, notice: "Cart was successfully destroyed."
  end

  private

  # Why we refused the postcode, in the customer's terms. :undeliverable means a
  # valid postcode somewhere we don't ship (the Crown Dependencies), so saying we
  # didn't recognise it would be untrue and would invite a pointless retry.
  def delivery_postcode_error(zone)
    if zone == :undeliverable
      "Sorry, we don't deliver to the Channel Islands or the Isle of Man."
    else
      "We didn't recognise that postcode. Please check it and try again."
    end
  end

  def eager_load_cart
    # Eager load cart items with their associations to prevent N+1 queries
    Current.cart.cart_items.includes(
      product: :product_photo_attachment
    ).load if Current.cart
  end

  def cart_params
    params.expect(cart: [ :user_id ])
  end
end
