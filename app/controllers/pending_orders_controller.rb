# frozen_string_literal: true

class PendingOrdersController < ApplicationController
  # Token-based authentication - no login required
  allow_unauthenticated_access

  before_action :set_pending_order_from_token
  before_action :ensure_pending_status, only: [ :confirm, :edit, :update ]

  # POST /pending-orders/:id/confirm?token=xxx
  def confirm
    return unless validate_token_for!("pending_order_confirm")

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    if result.success?
      flash[:notice] = "Your order has been confirmed!"
      redirect_to confirmation_order_path(result.order)
    else
      flash[:alert] = result.error
      render :payment_failed, status: :unprocessable_entity
    end
  end

  # GET /pending-orders/:id/edit?token=xxx
  def edit
    validate_token_for!("pending_order_edit")
  end

  # PATCH /pending-orders/:id?token=xxx
  def update
    return unless validate_token_for!("pending_order_edit")

    items = pending_order_params[:items] || []

    if items.empty?
      flash[:alert] = "Cannot save an empty order"
      render :edit, status: :unprocessable_entity
      return
    end

    if items.any? { |item| item[:quantity].to_i <= 0 }
      flash[:alert] = "Quantity must be greater than zero"
      render :edit, status: :unprocessable_entity
      return
    end

    new_snapshot = rebuild_snapshot(items)
    @pending_order.update!(items_snapshot: new_snapshot)

    flash[:notice] = "Order updated successfully"
    redirect_to edit_pending_order_path(@pending_order, token: @pending_order.edit_token)
  end

  private

  def set_pending_order_from_token
    token = params[:token]
    return render_not_found unless token.present?

    # Try to locate from either token type
    @pending_order = locate_from_token(token, "pending_order_confirm") ||
                     locate_from_token(token, "pending_order_edit")

    # Verify token resolves to the pending order in the URL path
    if @pending_order.nil? || @pending_order.id.to_s != params[:id]
      render_not_found
    end
  end

  def locate_from_token(token, purpose)
    GlobalID::Locator.locate_signed(token, for: purpose)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def validate_token_for!(purpose)
    token = params[:token]
    located = locate_from_token(token, purpose)

    if located.nil? || located != @pending_order
      render_not_found
      return false
    end
    true
  end

  def ensure_pending_status
    return if @pending_order.pending?

    render plain: "This order has already been processed or has expired",
           status: :gone
  end

  def pending_order_params
    params.require(:pending_order).permit(items: [ :product_variant_id, :quantity ])
  end

  def rebuild_snapshot(items)
    # Build new snapshot with provided items
    available_items = items.filter_map do |item|
      variant = ProductVariant.find_by(id: item[:product_variant_id])
      next unless variant&.active? && variant.product&.active?

      current_price = variant.price
      quantity = item[:quantity].to_i

      {
        "product_variant_id" => variant.id,
        "product_name" => variant.product&.name || "Unknown Product",
        "variant_name" => variant.display_name,
        "quantity" => quantity,
        "price" => "%.2f" % current_price,
        "line_total" => "%.2f" % (current_price * quantity),
        "available" => true
      }
    end

    subtotal = available_items.sum { |i| i["line_total"].to_d }
    vat = subtotal * VAT_RATE
    shipping = subtotal >= Shipping::FREE_SHIPPING_THRESHOLD ? 0 : (Shipping::STANDARD_COST / 100.0)
    total = subtotal + vat + shipping

    {
      "items" => available_items,
      "subtotal" => "%.2f" % subtotal,
      "vat" => "%.2f" % vat,
      "shipping" => "%.2f" % shipping,
      "total" => "%.2f" % total,
      "unavailable_items" => []
    }
  end

  def render_not_found
    render plain: "Not Found", status: :not_found
  end
end
