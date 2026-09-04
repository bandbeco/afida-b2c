module Webhooks
  class AgenticCheckoutController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      payload = request.body.read
      secret = Rails.application.credentials.dig(:stripe, :agentic_hook_secret)

      unless secret.present?
        Rails.logger.error("[Agentic Hook] Missing agentic_hook_secret in credentials; returning no customization")
        render json: {}
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
