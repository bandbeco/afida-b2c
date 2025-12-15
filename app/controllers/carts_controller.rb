class CartsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session  # Need user context for subscription toggle
  before_action :eager_load_cart, only: :show

  def show
    @cart_items = Current.cart.cart_items
      .includes(:product, product_variant: :product)
      .order("products.name ASC, product_variants.name ASC")
  end

  def destroy
    @cart.destroy
    redirect_to root_path, notice: "Cart was successfully destroyed."
  end

  private

  def eager_load_cart
    # Eager load cart items with their associations to prevent N+1 queries
    Current.cart.cart_items.includes(
      product_variant: [
        :product_photo_attachment,
        { product: :product_photo_attachment }
      ]
    ).load if Current.cart
  end

  def cart_params
    params.expect(cart: [ :user_id ])
  end
end
