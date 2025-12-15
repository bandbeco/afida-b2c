# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :require_authentication
  before_action :set_subscription, only: [ :destroy, :pause, :resume ]

  def index
    @subscriptions = Current.user.subscriptions.order(created_at: :desc)
  end

  def destroy
    if @subscription.cancelled?
      redirect_to subscriptions_path, alert: "This subscription has already been cancelled."
      return
    end

    @subscription.cancel!
    redirect_to subscriptions_path, notice: "Your subscription has been cancelled."
  end

  def pause
    if @subscription.paused?
      redirect_to subscriptions_path, alert: "This subscription is already paused."
      return
    end

    if @subscription.cancelled?
      redirect_to subscriptions_path, alert: "A cancelled subscription cannot be paused."
      return
    end

    @subscription.pause!
    redirect_to subscriptions_path, notice: "Your subscription has been paused."
  end

  def resume
    if @subscription.active?
      redirect_to subscriptions_path, alert: "This subscription is already active."
      return
    end

    if @subscription.cancelled?
      redirect_to subscriptions_path, alert: "A cancelled subscription cannot be resumed."
      return
    end

    @subscription.resume!
    redirect_to subscriptions_path, notice: "Your subscription has been resumed."
  end

  private

  def set_subscription
    @subscription = Current.user.subscriptions.find_by(id: params[:id])
    head :not_found unless @subscription
  end
end
