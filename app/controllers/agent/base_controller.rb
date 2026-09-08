# frozen_string_literal: true

module Agent
  class BaseController < ActionController::API
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    after_action :allow_cross_origin

    # CORS preflight. A cross-origin browser client sends OPTIONS before any
    # JSON POST, and a route that does not answer it never sees the POST.
    def preflight
      head :no_content
    end

    private

    def allow_cross_origin
      response.headers["Access-Control-Allow-Origin"] = "*"
      response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, MCP-Protocol-Version"
    end

    def discovery
      @discovery ||= Agent::Discovery.new(base_url: request.base_url)
    end

    def catalog
      @catalog ||= Agent::Catalog.new(base_url: request.base_url)
    end
  end
end
