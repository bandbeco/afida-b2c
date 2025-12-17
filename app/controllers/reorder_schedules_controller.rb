# frozen_string_literal: true

class ReorderSchedulesController < ApplicationController
  before_action :set_schedule, only: [ :show, :edit, :update, :pause, :resume, :skip_next, :destroy ]
  before_action :set_order, only: [ :setup, :create ]

  # GET /reorder_schedules
  def index
    @schedules = Current.user.reorder_schedules.includes(
      reorder_schedule_items: { product_variant: { product_photo_attachment: :blob, product: { product_photo_attachment: :blob } } }
    )
  end

  # GET /reorder_schedules/:id
  def show
  end

  # GET /reorder_schedules/setup?order_id=X
  def setup
    unless Current.user.has_saved_addresses?
      flash[:alert] = "Please add a delivery address before setting up a reorder schedule."
      redirect_to new_account_address_path(return_to: setup_reorder_schedules_path(order_id: @order.id))
      return
    end

    @frequencies = ReorderSchedule.frequencies.keys
  end

  # POST /reorder_schedules
  def create
    unless Current.user.has_saved_addresses?
      flash[:alert] = "Please add a delivery address before setting up a reorder schedule."
      redirect_to new_account_address_path
      return
    end

    frequency = reorder_schedule_params[:frequency]

    service = ReorderScheduleSetupService.new(user: Current.user)
    result = service.create_stripe_session(
      order: @order,
      frequency: frequency,
      success_url: setup_success_reorder_schedules_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: setup_cancel_reorder_schedules_url
    )

    if result.success?
      redirect_to result.session.url, allow_other_host: true, status: :see_other
    else
      flash[:alert] = "Unable to set up payment method: #{result.error}"
      redirect_to order_path(@order)
    end
  end

  # GET /reorder_schedules/setup_success?session_id=X
  def setup_success
    service = ReorderScheduleSetupService.new(user: Current.user)

    # Get frequency from session metadata
    session = Stripe::Checkout::Session.retrieve(params[:session_id])
    frequency = session.metadata["frequency"]

    result = service.complete_setup(
      session_id: params[:session_id],
      frequency: frequency
    )

    if result.success?
      flash[:notice] = "Your reorder schedule has been set up successfully!"
      redirect_to reorder_schedule_path(result.schedule)
    else
      flash[:alert] = "Unable to complete setup: #{result.error}"
      redirect_to orders_path
    end
  end

  # GET /reorder_schedules/setup_cancel
  def setup_cancel
    flash[:notice] = "Reorder schedule setup was cancelled."
    redirect_to orders_path
  end

  # PATCH /reorder_schedules/:id/pause
  def pause
    @schedule.pause! unless @schedule.paused?
    flash[:notice] = "Your reorder schedule has been paused."
    redirect_to reorder_schedule_path(@schedule)
  end

  # PATCH /reorder_schedules/:id/resume
  def resume
    @schedule.resume! if @schedule.paused?
    flash[:notice] = "Your reorder schedule has been resumed."
    redirect_to reorder_schedule_path(@schedule)
  end

  # DELETE /reorder_schedules/:id
  def destroy
    @schedule.cancel!
    flash[:notice] = "Your reorder schedule has been cancelled."
    redirect_to reorder_schedules_path
  end

  # PATCH /reorder_schedules/:id/skip_next
  def skip_next
    unless @schedule.active?
      flash[:alert] = "Cannot skip delivery for a #{@schedule.status} schedule."
      redirect_to reorder_schedule_path(@schedule)
      return
    end

    # Expire any pending orders for this schedule
    @schedule.pending_orders.pending.find_each(&:expire!)

    # Advance to the next date
    @schedule.advance_schedule!

    flash[:notice] = "Your next delivery has been skipped."
    redirect_to reorder_schedule_path(@schedule)
  end

  # GET /reorder_schedules/:id/edit
  def edit
    @frequencies = ReorderSchedule.frequencies.keys
  end

  # PATCH /reorder_schedules/:id
  def update
    if @schedule.update(schedule_update_params)
      flash[:notice] = "Your reorder schedule has been updated."
      redirect_to reorder_schedule_path(@schedule)
    else
      @frequencies = ReorderSchedule.frequencies.keys
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def reorder_schedule_params
    params.require(:reorder_schedule).permit(:order_id, :frequency)
  end

  def schedule_update_params
    params.require(:reorder_schedule).permit(
      :frequency,
      reorder_schedule_items_attributes: [ :id, :product_variant_id, :quantity, :price, :_destroy ]
    )
  end

  def set_schedule
    @schedule = Current.user.reorder_schedules.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to reorder_schedules_path, alert: "Schedule not found"
  end

  def set_order
    order_id = params[:order_id] || reorder_schedule_params[:order_id]
    @order = Current.user.orders.find(order_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to orders_path, alert: "Order not found"
  end
end
