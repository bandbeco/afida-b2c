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
    @product = @cart_item.product
    product_name = @product.display_name
    # Capture data for GA4 tracking before destroying
    @removed_quantity = @cart_item.quantity
    @removed_value = @cart_item.subtotal_amount
    # Use the item's own state to determine if it's a sample (more reliable than referer/params)
    is_sample_removal = @cart_item.sample?
    @category = @product.category if is_sample_removal
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

    # Calculate unit price and actual quantity from configuration
    unless params[:calculated_price].present?
      return render json: { error: "Calculated price is required" },
                    status: :unprocessable_entity
    end

    total_price = BigDecimal(params[:calculated_price].to_s)
    quantity = params[:configuration][:quantity].to_i
    unit_price = total_price / quantity

    @cart_item = @cart.cart_items.build(
      product: product,
      quantity: quantity,  # Actual quantity from configuration
      price: unit_price,   # Unit price (so SUM(price * quantity) works)
      configuration: params[:configuration],
      calculated_price: total_price
    )

    if params[:design].present?
      @cart_item.design.attach(params[:design])
    end

    if @cart_item.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to cart_path, notice: "Configured product added to cart" }
        format.json { render json: { success: true, cart_item: @cart_item }, status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("cart_counter", partial: "shared/cart_counter") }
        format.html { redirect_back fallback_location: root_path, alert: @cart_item.errors.full_messages.join(", ") }
        format.json { render json: { error: @cart_item.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def create_sample_cart_item
    # Find product ensuring it's active and sample-eligible
    @product = Product.active.sample_eligible.find_by(id: sample_params)

    unless @product
      return respond_with_sample_error("This product is not available as a sample")
    end

    # Check sample limit
    if @cart.at_sample_limit?
      return respond_with_sample_error("Sample limit of #{Cart::SAMPLE_LIMIT} reached")
    end

    # Check if sample already in cart (allow regular item to coexist)
    if @cart.cart_items.samples.exists?(product: @product)
      return respond_with_sample_error("This sample is already in your cart")
    end

    @cart_item = @cart.cart_items.build(
      product: @product,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    if @cart_item.save
      @sample_count = @cart.sample_count
      @at_limit = @cart.at_sample_limit?
      @category = @product.category
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
    @in_cart = @product && @cart.cart_items.exists?(product: @product)
    @at_limit = @cart.at_sample_limit?

    respond_to do |format|
      format.turbo_stream { render :create_sample_error }
      format.html { redirect_to samples_path, alert: message }
    end
  end

  def create_standard_cart_item
    # Find product by SKU
    product = Product.find_by!(sku: cart_item_params[:sku])

    # Wrap in transaction to ensure sample removal and item creation are atomic
    # If save fails, sample won't be lost
    ActiveRecord::Base.transaction do
      # If sample exists for this product, remove it (regular item replaces sample)
      sample_items = @cart.cart_items.samples.where(product: product)
      @sample_replaced = sample_items.exists?
      sample_items.destroy_all

      # Find existing non-sample cart item for this product
      @cart_item = @cart.cart_items.non_samples.find_by(product: product)

      # If no regular item exists, create a new one
      @cart_item ||= @cart.cart_items.build(product: product)

      if @cart_item.new_record?
        @cart_item.quantity = cart_item_params[:quantity].to_i || 1
        @cart_item.price = product.price
      else
        @cart_item.quantity += (cart_item_params[:quantity].to_i || 1)
      end

      # Use save! to raise on failure and trigger rollback
      @cart_item.save!
    end

    # Transaction succeeded
    respond_to do |format|
      format.turbo_stream
      # Renders create.turbo_stream.erb which handles:
      # - Cart counter update
      # - Drawer content update
      # - Sample replacement notification (if @sample_replaced)
      # Note: Modal clearing handled by quick_add_modal_controller.js on turbo:submit-end
      format.html do
        notice = if @sample_replaced
          "#{product.display_name} added to cart (sample removed)."
        else
          "#{product.display_name} added to cart."
        end
        redirect_to cart_path, notice: notice
      end
    end
  rescue ActiveRecord::RecordInvalid
    # Transaction rolled back - sample not removed, cart item not saved
    @sample_replaced = false
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: product_path(product), alert: "Could not add item to cart: #{@cart_item.errors.full_messages.join(', ')}" }
    end
  end

  def cart_item_params
    params.expect(cart_item: [ :sku, :quantity ])
  end

  def sample_params
    params.expect(:product_id)
  end
end
