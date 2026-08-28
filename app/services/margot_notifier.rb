# frozen_string_literal: true

require "http"

# Asks Margot (our OpenClaw research agent) to research a prospect by posting
# an agent run to her Gateway webhook. Margot researches the customer and
# delivers her findings to the Afida Telegram group herself, so this bypasses
# Telegram's bot-to-bot delivery restrictions entirely.
#
# Fire-and-forget: this service never raises. Missing credentials, an outage,
# or a network error is logged and swallowed so it can never break the order
# flow. Callers should enqueue it via MargotResearchJob.
#
# Gateway webhook reference: https://docs.openclaw.ai/automation/cron-jobs#webhooks
#
# Credentials:
#   margot:
#     gateway_url: https://<margot-gateway-host>
#     hook_token: <hooks.token from Margot's OpenClaw config>
#
class MargotNotifier
  include ActionView::Helpers::NumberHelper

  TIMEOUT_SECONDS = 10

  class << self
    # Asks Margot to research the order's customer.
    # @param order [Order]
    # @return [Boolean] true if the gateway accepted the run, false otherwise
    def request_research(order)
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

    send_hook
  rescue HTTP::Error, HTTP::TimeoutError => e
    log_error("HTTP error: #{e.class} - #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error: #{e.class} - #{e.message}")
    false
  end

  private

  def send_hook
    response = HTTP
      .timeout(TIMEOUT_SECONDS)
      .auth("Bearer #{hook_token}")
      .post("#{gateway_url}/hooks/agent", json: payload)

    if response.status.success?
      Rails.logger.info("[Margot] Research requested for order #{@order.display_number}")
      true
    else
      log_error("Gateway returned #{response.status}: #{response.body}")
      false
    end
  end

  def payload
    {
      message: research_prompt,
      name: "Research prospect #{@order.display_number}",
      # Margot's agent id. Session management is deliberately left to her
      # OpenClaw config (hooks.defaultSessionKey), so all order-research
      # runs share one dedicated persistent session that the caller
      # cannot redirect.
      agentId: "afida",
      deliver: true,
      channel: "telegram",
      to: chat_id
    }
  end

  def research_prompt
    items = @order.order_items.map { |item| "#{item.quantity}x #{item.product_name}" }.join(", ")

    <<~PROMPT
      New first-time customer order #{@order.display_number} on afida.com — research this prospect properly, the way you do when we tag you in the group. This session has no chat history: search your memory for anything we already know about this customer, and research the web for everything else.

      Customer: #{customer_name} (#{@order.email})
      Shipping address: #{@order.full_shipping_address}
      Order: #{items} — total #{number_to_currency(@order.total_amount, unit: "£")}

      Dig deep:
      - Identify the actual business behind the order: trading name, venue, what they sell. The email and shipping address are your best leads — and check whether the address is a second or new location (opening stock is a strong buying signal).
      - Companies House: registered company, directors, incorporation date, latest filings, what the finances suggest.
      - Reviews and reach: Google and Tripadvisor ratings with review counts, delivery platforms, website, social presence, and whether the owner engages personally.
      - Contacts: phone, public emails, and who the likely buyer is.
      - The sales angle: what this order says about their operation and what recurring packaging needs they will have.

      Post your findings to the group in your usual style: lead with the most interesting insight, score the prospect out of 10 with your reasoning, include links, and keep it punchy. If you can't confirm something, say so rather than padding.
    PROMPT
  end

  def customer_name
    @order.shipping_name.presence || @order.email
  end

  def credentials_configured?
    gateway_url.present? && hook_token.present? && chat_id.present?
  end

  def gateway_url
    Rails.application.credentials.dig(:margot, :gateway_url)
  end

  def hook_token
    Rails.application.credentials.dig(:margot, :hook_token)
  end

  # Margot posts her findings into the same group the order notification
  # goes to.
  def chat_id
    Rails.application.credentials.dig(:telegram, :chat_id)
  end

  def log_error(message)
    Rails.logger.error("[Margot] FAILED order='#{@order&.id}' error='#{message}'")
  end
end
