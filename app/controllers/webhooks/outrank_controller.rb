# frozen_string_literal: true

module Webhooks
  # Receives webhook payloads from Outrank.so SEO content platform.
  #
  # Articles are imported as draft BlogPosts for admin review.
  # Authenticates via Bearer token in Authorization header.
  #
  # POST /webhooks/outrank
  #
  # Security layers:
  #   1. Rate limiting: 100 requests per hour per IP
  #   2. Bearer token authentication (required)
  #
  class OutrankController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    # Rate limit: 100 requests per hour per IP address
    rate_limit to: 100, within: 1.hour,
               by: -> { request.remote_ip },
               with: -> { render_rate_limited }

    before_action :verify_access_token

    def create
      result = Outrank::WebhookProcessor.new(webhook_params).call

      render json: result, status: :ok
    end

    private

    # Verifies Bearer token matches configured access token.
    # Uses timing-safe comparison to prevent timing attacks.
    def verify_access_token
      auth_header = request.headers["Authorization"]

      unless auth_header&.start_with?("Bearer ")
        render_unauthorized
        return
      end

      token = auth_header.split(" ", 2).last
      expected_token = Rails.application.credentials.dig(:outrank, :access_token)

      unless expected_token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
        render_unauthorized
      end
    end

    def render_unauthorized
      render json: {
        error: "Unauthorized",
        message: "Invalid or missing access token"
      }, status: :unauthorized
    end

    def render_rate_limited
      render json: {
        error: "Too Many Requests",
        message: "Rate limit exceeded. Please try again later."
      }, status: :too_many_requests
    end

    def webhook_params
      params.permit(
        :event_type,
        :timestamp,
        data: { articles: [ :id, :title, :slug, :content_markdown, :content_html,
                           :meta_description, :image_url, :created_at, tags: [] ] }
      ).to_h
    end
  end
end
