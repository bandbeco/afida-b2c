# frozen_string_literal: true

# Subscribes to Rails.event events and routes them to DataFast as goals.
#
# Goals are tracked asynchronously via DatafastGoalJob to avoid
# blocking user requests.
#
# Event → Goal Mapping:
#   cart.item_added       → add_to_cart
#   cart.item_removed     → remove_from_cart
#   checkout.started      → begin_checkout
#   checkout.completed    → purchase
#   email_signup.completed → email_signup
#
# Usage:
#   Rails.event.subscribe(DatafastSubscriber.new)
#
class DatafastSubscriber
  # Map Rails events to DataFast goal names
  EVENT_GOAL_MAPPING = {
    "cart.item_added" => "add_to_cart",
    "cart.item_removed" => "remove_from_cart",
    "checkout.started" => "begin_checkout",
    "checkout.completed" => "purchase",
    "email_signup.completed" => "email_signup"
  }.freeze

  # Called by Rails.event for each event
  # @param event [Hash] Event with :name, :payload, :context keys
  def emit(event)
    goal_name = EVENT_GOAL_MAPPING[event[:name]]
    return unless goal_name

    visitor_id = event.dig(:context, :datafast_visitor_id)
    return if visitor_id.blank?

    metadata = build_metadata(event[:name], event[:payload])

    DatafastGoalJob.perform_later(goal_name, visitor_id: visitor_id, metadata: metadata)
  end

  private

  # Builds goal metadata from event payload, extracting relevant fields
  # @param event_name [String] The Rails event name
  # @param payload [Hash] The event payload
  # @return [Hash] Metadata for DataFast goal
  def build_metadata(event_name, payload)
    case event_name
    when "cart.item_added"
      {
        product_id: payload[:product_id],
        product_sku: payload[:product_sku],
        quantity: payload[:quantity]
      }
    when "cart.item_removed"
      {
        product_id: payload[:product_id],
        product_sku: payload[:product_sku]
      }
    when "checkout.started"
      {
        cart_id: payload[:cart_id],
        item_count: payload[:item_count],
        subtotal: payload[:subtotal]&.to_s
      }
    when "checkout.completed"
      {
        order_id: payload[:order_id],
        total: payload[:total]&.to_s
      }
    when "email_signup.completed"
      {
        source: payload[:source]
      }
    else
      {}
    end.compact
  end
end
