# frozen_string_literal: true

class PendingOrdersController < ApplicationController
  # Token-based authentication - no login required
  allow_unauthenticated_access

  before_action :set_pending_order_from_token
  before_action :ensure_pending_status, only: [ :show, :confirm, :edit, :update, :update_payment_method ]

  # GET /pending-orders/:id?token=xxx
  # Landing page from email - shows order details with confirm button
  def show
    return unless validate_token_for!("pending_order_confirm")

    @schedule = @pending_order.reorder_schedule
  end

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

  # POST /pending-orders/:id/update_payment_method?token=xxx
  # Redirects to Stripe Checkout to collect new payment method
  def update_payment_method
    return unless validate_token_for!("pending_order_confirm")

    @schedule = @pending_order.reorder_schedule
    user = @schedule.user

    # Ensure user has a Stripe customer ID
    customer_id = ensure_stripe_customer(user)

    session = Stripe::Checkout::Session.create(
      mode: "setup",
      customer: customer_id,
      payment_method_types: [ "card" ],
      success_url: update_payment_method_success_pending_order_url(
        @pending_order,
        token: @pending_order.confirmation_token,
        session_id: "{CHECKOUT_SESSION_ID}"
      ),
      cancel_url: pending_order_url(
        @pending_order,
        token: @pending_order.confirmation_token
      ),
      metadata: {
        pending_order_id: @pending_order.id.to_s,
        schedule_id: @schedule.id.to_s
      }
    )

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    flash[:alert] = "Could not connect to payment provider: #{e.message}"
    redirect_to pending_order_path(@pending_order, token: @pending_order.confirmation_token)
  end

  # GET /pending-orders/:id/update_payment_method_success?token=xxx&session_id=xxx
  # Updates payment method on schedule and retries the charge
  def update_payment_method_success
    return unless validate_token_for!("pending_order_confirm")

    session_id = params[:session_id]
    unless session_id.present?
      flash[:alert] = "Invalid payment session"
      redirect_to pending_order_path(@pending_order, token: @pending_order.confirmation_token)
      return
    end

    # Retrieve session with expanded payment method
    session = Stripe::Checkout::Session.retrieve({
      id: session_id,
      expand: [ "setup_intent.payment_method" ]
    })

    payment_method = session.setup_intent.payment_method
    @schedule = @pending_order.reorder_schedule

    # Update the schedule with new payment method
    @schedule.update!(
      stripe_payment_method_id: payment_method.id,
      card_brand: payment_method.card&.brand,
      card_last4: payment_method.card&.last4
    )

    # Now retry the charge with the new payment method
    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    if result.success?
      flash[:notice] = "Payment method updated and order confirmed!"
      redirect_to confirmation_order_path(result.order)
    else
      flash[:alert] = result.error
      render :payment_failed, status: :unprocessable_entity
    end
  rescue Stripe::StripeError => e
    flash[:alert] = "Payment error: #{e.message}"
    redirect_to pending_order_path(@pending_order, token: @pending_order.confirmation_token)
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
    PendingOrderSnapshotBuilder.build_from_items(items)
  end

  def render_not_found
    render plain: "Not Found", status: :not_found
  end

  def ensure_stripe_customer(user)
    if user.stripe_customer_id.present?
      user.stripe_customer_id
    else
      customer = Stripe::Customer.create(
        email: user.email_address,
        metadata: { user_id: user.id }
      )
      user.update!(stripe_customer_id: customer.id)
      customer.id
    end
  end
end
