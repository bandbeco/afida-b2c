module Webhooks
  # Stripe Agentic Commerce checkout customization hook. Stripe POSTs a
  # v1.delegated_checkout.customize_checkout request before quoting an agent
  # checkout and waits (4 seconds) for the tax rates and shipping options in
  # the response body. A non-2xx becomes a 424 to the agent, so anything that
  # cannot be answered is refused with a 4xx here rather than guessed.
  class AgenticCheckoutController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      payload = request.body.read
      secret = Rails.application.credentials.dig(:stripe, :agentic_hook_secret)

      unless secret.present?
        Rails.logger.error("[Agentic Hook] Missing agentic_hook_secret in credentials")
        head :bad_request
        return
      end

      begin
        Stripe::Webhook::Signature.verify_header(payload, request.env["HTTP_STRIPE_SIGNATURE"].to_s, secret)
      rescue Stripe::SignatureVerificationError
        Rails.logger.error("[Agentic Hook] Invalid signature")
        head :bad_request
        return
      end

      begin
        hook = JSON.parse(payload)
      rescue JSON::ParserError
        Rails.logger.error("[Agentic Hook] Invalid JSON payload")
        head :bad_request
        return
      end

      render json: AgenticCommerce::CheckoutCustomization.new(hook["data"]).response
    end
  end
end
