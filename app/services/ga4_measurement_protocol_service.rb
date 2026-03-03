# frozen_string_literal: true

require "net/http"

class Ga4MeasurementProtocolService
  ENDPOINT = "https://www.google-analytics.com/mp/collect"

  class << self
    def track_purchase(order)
      new(order).track
    end
  end

  def initialize(order)
    @order = order
  end

  def track
    unless Rails.env.production?
      Rails.logger.info("[GA4 MP] Skipping — not in production (#{Rails.env})")
      return false
    end

    unless measurement_id.present? && api_secret.present?
      Rails.logger.info("[GA4 MP] Skipping — credentials not configured")
      return false
    end

    uri = URI("#{ENDPOINT}?measurement_id=#{measurement_id}&api_secret=#{api_secret}")

    response = Net::HTTP.post(
      uri,
      payload.to_json,
      "Content-Type" => "application/json"
    )

    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.error("[GA4 MP] Error sending purchase event for order #{@order.order_number}: #{e.class} - #{e.message}")
    false
  end

  private

  def payload
    {
      client_id: client_id,
      events: [ {
        name: "purchase",
        params: purchase_params
      } ]
    }
  end

  def purchase_params
    params = {
      transaction_id: @order.order_number,
      value: @order.total_amount.to_f,
      tax: @order.vat_amount.to_f,
      shipping: @order.shipping_amount.to_f,
      currency: "GBP",
      items: items
    }

    if @order.discount_amount.to_f > 0
      params[:coupon] = @order.discount_code if @order.discount_code.present?
      params[:discount] = @order.discount_amount.to_f
    end

    params
  end

  def items
    @order.order_items.includes(:product).map do |item|
      {
        item_id: item.product_sku,
        item_name: item.product_name,
        item_category: item.product&.category&.name,
        price: item.unit_price.to_f,
        quantity: item.quantity
      }.compact
    end
  end

  def client_id
    Digest::SHA256.hexdigest("order_#{@order.id}")[0, 36]
  end

  def measurement_id
    Rails.application.credentials.dig(:ga4, :measurement_id)
  end

  def api_secret
    Rails.application.credentials.dig(:ga4, :api_secret)
  end
end
