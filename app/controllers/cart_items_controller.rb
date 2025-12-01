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
    elsif params[:sample].present?
      # Sample request
      create_sample_cart_item
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
    @variant = @cart_item.product_variant
    product_name = @variant.display_name
    # Use the item's own state to determine if it's a sample (more reliable than referer/params)
    is_sample_removal = @cart_item.sample?
    @category = @variant.product.category if is_sample_removal
    @cart_item.destroy

    respond_to do |format|
      format.turbo_stream do
        if is_sample_removal
          @sample_count = @cart.sample_count
          @at_limit = @cart.at_sample_limit?
          @category_selected_count = @cart.sample_count_for_category(@category)
          render :destroy_sample
        else
          render :destroy
        end
      end
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

  def create_sample_cart_item
    # Find variant ensuring it's active and sample-eligible
    @variant = ProductVariant.active.sample_eligible.find_by(id: params[:product_variant_id])

    unless @variant
      return respond_with_sample_error("This variant is not available as a sample")
    end

    # Check sample limit
    if @cart.at_sample_limit?
      return respond_with_sample_error("Sample limit reached (#{Cart::SAMPLE_LIMIT} maximum)")
    end

    # Check if sample already in cart (allow regular item to coexist)
    if @cart.cart_items.samples.exists?(product_variant: @variant)
      return respond_with_sample_error("This sample is already in your cart")
    end

    @cart_item = @cart.cart_items.build(
      product_variant: @variant,
      quantity: 1,
      price: 0
    )

    if @cart_item.save
      @sample_count = @cart.sample_count
      @at_limit = @cart.at_sample_limit?
      @category = @variant.product.category
      @category_selected_count = @cart.sample_count_for_category(@category)

      respond_to do |format|
        format.turbo_stream { render :create_sample }
        format.html { redirect_to samples_path, notice: "Sample added to cart" }
      end
    else
      respond_with_sample_error(@cart_item.errors.full_messages.join(", "))
    end
  end

  def respond_with_sample_error(message)
    @error_message = message
    @in_cart = @variant && @cart.cart_items.exists?(product_variant: @variant)
    @at_limit = @cart.at_sample_limit?

    respond_to do |format|
      format.turbo_stream { render :create_sample_error }
      format.html { redirect_to samples_path, alert: message }
    end
  end

  def create_standard_cart_item
    # Existing logic for standard products
    product_variant = ProductVariant.find_by!(sku: cart_item_params[:variant_sku])

    # Find existing non-sample cart item for this variant
    @cart_item = @cart.cart_items.non_samples.find_by(product_variant: product_variant)

    # If no regular item exists, create a new one
    @cart_item ||= @cart.cart_items.build(product_variant: product_variant)

    if @cart_item.new_record?
      @cart_item.quantity = cart_item_params[:quantity].to_i || 1
      @cart_item.price = product_variant.price
    else
      @cart_item.quantity += (cart_item_params[:quantity].to_i || 1)
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

  def cart_item_params
    params.expect(cart_item: [ :variant_sku, :quantity ])
  end
end
