# frozen_string_literal: true

require "http"

# Sends order notifications to Afida's Telegram group chat via the Bot API.
#
# Fire-and-forget: this service never raises. A misconfigured token, an API
# outage, or a network error is logged and swallowed so it can never break the
# order flow. Callers should enqueue it via TelegramOrderNotificationJob.
#
# API Reference: https://core.telegram.org/bots/api#sendmessage
#
# Usage:
#   TelegramNotifier.notify_new_order(order)
#
class TelegramNotifier
  include ActionView::Helpers::NumberHelper

  API_BASE = "https://api.telegram.org"
  TIMEOUT_SECONDS = 5
  MAX_MESSAGE_LENGTH = 4096
  MAX_ITEM_LINES = 25

  class << self
    # Notifies the group chat that a new order has been placed.
    # @param order [Order]
    # @return [Boolean] true if delivered, false otherwise
    def notify_new_order(order)
      new(order).deliver
    end
  end

  def initialize(order)
    @order = order
  end

  def deliver
    unless credentials_configured?
      log_error("credentials not configured")
      return false
    end

    send_message
  rescue HTTP::Error, HTTP::TimeoutError => e
    log_error("HTTP error: #{e.class} - #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error: #{e.class} - #{e.message}")
    false
  end

  private

  def send_message
    response = HTTP
      .timeout(TIMEOUT_SECONDS)
      .post(send_message_url, json: payload)

    if response.status.success?
      Rails.logger.info("[Telegram] Notified new order #{@order.display_number}")
      true
    else
      log_error("API returned #{response.status}: #{response.body}")
      false
    end
  end

  def payload
    {
      chat_id: chat_id,
      text: build_message,
      parse_mode: "HTML",
      link_preview_options: { is_disabled: true }
    }
  end

  def build_message
    items = @order.order_items.to_a
    line_items_count = items.size
    units_count = items.sum { |item| item.quantity.to_i }

    lines = []
    lines << "🛒 <b>New order #{esc(@order.display_number)}</b>"
    lines << ""
    lines << "👤 #{esc(customer_name)} (#{esc(@order.email)})"
    lines << "📦 #{line_items_count} line items / #{units_count} units · Total #{esc(formatted_total)}"

    if items.any?
      lines << ""
      items.first(MAX_ITEM_LINES).each do |item|
        suffix = item.sample? ? " (Sample)" : ""
        lines << "• #{item.quantity}× #{esc(item.product_name)}#{suffix}"
      end
      if items.size > MAX_ITEM_LINES
        lines << "… and #{items.size - MAX_ITEM_LINES} more"
      end
    end

    lines << ""
    lines << "🔗 #{esc(admin_url)}"

    truncate_message(lines.join("\n"))
  end

  # Telegram rejects messages whose HTML doesn't parse, so a hard slice must
  # not leave a partial entity (e.g. "&amp;" cut to "&am") at the end.
  def truncate_message(text)
    return text if text.length <= MAX_MESSAGE_LENGTH

    text.first(MAX_MESSAGE_LENGTH).sub(/&[a-zA-Z#0-9]*\z/, "")
  end

  def customer_name
    @order.shipping_name.presence || @order.email
  end

  def formatted_total
    number_to_currency(@order.total_amount, unit: "£")
  end

  def admin_url
    Rails.application.routes.url_helpers.admin_order_url(@order, **url_options)
  end

  # Action Mailer's host is configured in every environment (test, development,
  # production), unlike routes.default_url_options which is only set in some, so
  # derive the host from there for a reliable URL outside a request context.
  def url_options
    Rails.application.config.action_mailer.default_url_options || {}
  end

  def esc(value)
    CGI.escapeHTML(value.to_s)
  end

  def send_message_url
    "#{API_BASE}/bot#{bot_token}/sendMessage"
  end

  def credentials_configured?
    bot_token.present? && chat_id.present?
  end

  def bot_token
    Rails.application.credentials.dig(:telegram, :bot_token)
  end

  def chat_id
    Rails.application.credentials.dig(:telegram, :chat_id)
  end

  def log_error(message)
    Rails.logger.error("[Telegram] FAILED order='#{@order&.id}' error='#{message}'")
  end
end
