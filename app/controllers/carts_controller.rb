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

  def destroy
    @cart.destroy
    redirect_to root_path, notice: "Cart was successfully destroyed."
  end

  private

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
