# frozen_string_literal: true

# Bearer-token authentication for internal API endpoints.
#
# Reads the token from the Authorization header and compares it against
# the internal_api_token stored in Rails credentials using secure comparison.
module ApiTokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token
  end

  private

  def authenticate_api_token
    expected = Rails.application.credentials.internal_api_token

    if expected.blank?
      render json: { error: "API authentication is not configured" }, status: :service_unavailable
      return
    end

    provided = request.headers["Authorization"]&.delete_prefix("Bearer ")

    unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
