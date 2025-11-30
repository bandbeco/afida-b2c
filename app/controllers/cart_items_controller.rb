class CartItemsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute, only: [ :create, :update, :destroy ], with: -> { redirect_to cart_path, alert: "Too many cart operations. Please slow down." }

  before_action :set_cart
  before_action :set_cart_item, only: [ :update, :destroy ]

  # POST /cart/cart_items
  def create
    @cart = Current.cart

    if params[:configuration].present?
      # Configured product (branded cups)
      create_configured_cart_item
    else
      # Standard product
      create_standard_cart_item
    end
  end

  # PATCH/PUT /cart/cart_items/:id
  def update
    new_quantity = cart_item_params[:quantity].to_i
    if new_quantity <= 0
      # If quantity is zero or less, remove the item instead
      @cart_item.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cart_path, notice: "Item removed from cart." }
      end
    elsif @cart_item.update(quantity: new_quantity)
      @cart_item.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cart_path, notice: "Cart updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("cart_counter", partial: "shared/cart_counter") }
        format.html { redirect_to cart_path, alert: "Could not update cart: #{@cart_item.errors.full_messages.join(', ')}" }
      end
    end
  end

  # DELETE /cart/cart_items/:id
  def destroy
    product_name = @cart_item.product_variant.display_name
    @cart_item.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cart_path, notice: "#{product_name} removed from cart.", status: :see_other }
    end
  end

  private

  # Ensures that there is a cart available for the current session/user.
  # This relies on Current.cart being set by ApplicationController or similar.
  def set_cart
    @cart = Current.cart

    unless @cart
      set_current_cart
      @cart = Current.cart
    end
  end

  def set_cart_item
    @cart_item = @cart.cart_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cart_path, alert: "Cart item not found."
  end

  def create_configured_cart_item
    product = Product.find(params[:product_id])

    unless product.customizable_template?
      return render json: { error: "Product is not customizable" },
                    status: :unprocessable_entity
    end

    # For configured products, use the first variant as a placeholder
    product_variant = product.active_variants.first
    unless product_variant
      return render json: { error: "Product has no available variants" },
                    status: :unprocessable_entity
    end

    # Calculate unit price and actual quantity from configuration
    unless params[:calculated_price].present?
      return render json: { error: "Calculated price is required" },
                    status: :unprocessable_entity
    end

    total_price = BigDecimal(params[:calculated_price].to_s)
    quantity = params[:configuration][:quantity].to_i
    unit_price = total_price / quantity

    cart_item = @cart.cart_items.build(
      product_variant: product_variant,
      quantity: quantity,  # Actual quantity from configuration
      price: unit_price,   # Unit price (so SUM(price * quantity) works)
      configuration: params[:configuration],
      calculated_price: total_price
    )

    if params[:design].present?
      cart_item.design.attach(params[:design])
    end

    if cart_item.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cart_path, notice: "Configured product added to cart" }
        format.json { render json: { success: true, cart_item: cart_item }, status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("cart_counter", partial: "shared/cart_counter") }
        format.html { redirect_back fallback_location: root_path, alert: cart_item.errors.full_messages.join(", ") }
        format.json { render json: { error: cart_item.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def create_standard_cart_item
    # Find variant by SKU or ID (samples page uses ID)
    product_variant = find_product_variant
    return unless product_variant

    # Check for sample pack limit (1 per order)
    if product_variant.product.sample_pack? && @cart.has_sample_pack?
      return redirect_to cart_path, notice: "Sample pack is already in your cart."
    end

    @cart_item = @cart.cart_items.find_or_initialize_by(product_variant: product_variant)

    if @cart_item.new_record?
      # For sample pack, always cap quantity at 1
      quantity = product_variant.product.sample_pack? ? 1 : (cart_item_quantity || 1)
      @cart_item.quantity = quantity
      @cart_item.price = product_variant.price
    else
      # For sample pack, don't increment quantity
      unless product_variant.product.sample_pack?
        @cart_item.quantity += (cart_item_quantity || 1)
      end
    end

    if @cart_item.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Update cart counter
            turbo_stream.replace("cart_counter", partial: "shared/cart_counter"),
            # Update drawer cart content
            turbo_stream.replace("drawer_cart_content", partial: "shared/drawer_cart_content")
            # Note: Modal clearing handled by quick_add_modal_controller.js on turbo:submit-end
          ]
        end
        format.html { redirect_to cart_path, notice: "#{product_variant.display_name} added to cart." }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: product_path(product_variant.product), alert: "Could not add item to cart: #{@cart_item.errors.full_messages.join(', ')}" }
      end
    end
  end

  # Find variant by SKU (from product page) or ID (from samples page)
  def find_product_variant
    if cart_item_params[:variant_sku].present?
      ProductVariant.find_by!(sku: cart_item_params[:variant_sku])
    elsif params[:product_variant_id].present?
      ProductVariant.find(params[:product_variant_id])
    else
      nil
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to cart_path, alert: "Product not found."
    nil
  end

  # Get quantity from nested params or top-level params
  def cart_item_quantity
    (cart_item_params[:quantity] || params[:quantity]).to_i
  end

  def cart_item_params
    return {} unless params[:cart_item].present?
    params.expect(cart_item: [ :variant_sku, :quantity ])
  end
end
