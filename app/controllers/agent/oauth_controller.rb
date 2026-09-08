# frozen_string_literal: true

module Agent
  class OauthController < BaseController
    rate_limit to: 20, within: 1.minute, with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

    def register
      application = OauthApplication.new(
        name: params[:client_name].presence || "agent",
        client_id: SecureRandom.uuid,
        client_secret: SecureRandom.hex(32)
      )
      secret = application.client_secret
      application.save!
      render json: {
        client_id: application.client_id,
        client_secret: secret,
        client_name: application.name,
        grant_types: [ "client_credentials" ],
        token_endpoint_auth_method: "client_secret_post"
      }, status: :created
    end

    def token
      unless params[:grant_type] == "client_credentials"
        render json: { error: "unsupported_grant_type" }, status: :bad_request
        return
      end

      application = OauthApplication.find_by(client_id: params[:client_id])
      unless application&.authenticate_client_secret(params[:client_secret].to_s)
        render json: { error: "invalid_client" }, status: :unauthorized
        return
      end

      now = Time.current.to_i
      token = Agent::Jwt.encode(
        "iss" => request.base_url,
        "sub" => application.client_id,
        "aud" => request.base_url,
        "iat" => now,
        "exp" => now + 3600,
        "jti" => SecureRandom.uuid,
        "scope" => "checkout.write"
      )
      render json: { access_token: token, token_type: "Bearer", expires_in: 3600 }
    end

    def jwks
      render json: Agent::Jwt.jwks
    end

    def authorize
      render plain: "Afida issues agent tokens with grant_type=client_credentials at #{request.base_url}/oauth/token. Register at #{request.base_url}/oauth/register. Humans sign in at #{request.base_url}/signin."
    end
  end
end
