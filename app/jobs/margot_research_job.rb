# frozen_string_literal: true

# Asks Margot (our OpenClaw research agent) to research the customer behind
# an order, but only for first-time customers - returning customers are
# already known.
#
# Fire-and-forget: discards any error so a Margot problem never affects the
# order flow. The notifier itself also swallows its own errors.
class MargotResearchJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(order_id)
    order = Order.includes(:order_items).find_by(id: order_id)
    return unless order&.new_customer?

    MargotNotifier.request_research(order)
  end
end
