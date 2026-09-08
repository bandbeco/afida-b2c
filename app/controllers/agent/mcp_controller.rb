# frozen_string_literal: true

module Agent
  class McpController < BaseController
    rate_limit to: 60, within: 1.minute, with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

    def handle
      if request.get? || request.head?
        render json: discovery.mcp_server_card
        return
      end

      payload = if request.raw_post.present?
        JSON.parse(request.raw_post)
      else
        params.to_unsafe_h
      end
      result = Agent::McpServer.new(base_url: request.base_url).handle(payload)
      if result == :no_content
        head :accepted
      else
        render json: result
      end
    rescue JSON::ParserError
      render json: { jsonrpc: "2.0", error: { code: -32700, message: "Parse error" }, id: nil }, status: :bad_request
    end
  end
end
