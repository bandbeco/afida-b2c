# frozen_string_literal: true

module Agent
  class WellKnownController < BaseController
    def api_catalog
      render json: discovery.api_catalog, content_type: "application/linkset+json"
    end

    def mcp_server_card
      render json: discovery.mcp_server_card
    end

    def agent_skills_index
      render json: discovery.agent_skills_index
    end

    def agent_skill
      skill = Agent::Skills.find(params[:name])
      raise ActiveRecord::RecordNotFound unless skill

      render plain: skill.body, content_type: "text/markdown; charset=utf-8"
    end

    def ard
      render json: discovery.ard
    end

    def oauth_authorization_server
      render json: discovery.oauth_authorization_server
    end

    def oauth_protected_resource
      render json: discovery.oauth_protected_resource
    end

    def ucp
      render json: discovery.ucp
    end

    def acp
      render json: discovery.acp
    end

    def auth_md
      render plain: discovery.auth_md, content_type: "text/markdown; charset=utf-8"
    end

    def openapi
      render json: Agent::Openapi.new(base_url: request.base_url).document
    end
  end
end
