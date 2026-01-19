# Controller for fixed sample pack landing pages
#
# These are conversion-focused landing pages for PPC/email campaigns.
# Each pack contains exactly 5 curated products - no pick-and-mix.
# Single CTA adds all products to cart and redirects to checkout.
#
# For pick-and-mix sample browsing, see SamplesController.
#
class SamplePacksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 30, within: 1.minute, only: [ :show, :request_pack ]

  # GET /sample-packs/:slug
  # Landing page for a fixed sample pack
  def show
    @sample_pack = Collection.sample_packs
                             .includes(image_attachment: :blob)
                             .find_by!(slug: params[:slug])
    @products = @sample_pack.sample_eligible_products
                            .includes(:category, product_photo_attachment: :blob)
                            .order("collection_items.position ASC")
                            .limit(Cart::SAMPLE_LIMIT)
    @client_logos = helpers.client_logos
  end

  # POST /sample-packs/:slug/request_pack
  # Adds all pack products to cart and redirects to checkout
  def request_pack
    @sample_pack = Collection.sample_packs.find_by!(slug: params[:slug])
    products = @sample_pack.sample_eligible_products
                           .limit(Cart::SAMPLE_LIMIT)
                           .to_a

    cart = Current.cart

    # Clear any existing samples to ensure clean pack experience
    cart.cart_items.samples.destroy_all

    added_count = 0

    products.each do |product|
      # Skip if product already in cart as regular (non-sample) item
      next if cart.cart_items.non_samples.exists?(product_id: product.id)

      cart.cart_items.create!(product: product, quantity: 1, price: 0, is_sample: true)
      added_count += 1
    end

    if added_count > 0
      redirect_to cart_path, notice: "#{@sample_pack.name} samples added to your cart!"
    else
      redirect_to cart_path, notice: "These products are already in your cart."
    end
  end
end
