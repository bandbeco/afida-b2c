# frozen_string_literal: true

# Bearer-token authentication for internal API endpoints.
#
# Reads the token from the Authorization header and compares it against
# the AFIDA_INTERNAL_API_TOKEN environment variable using secure comparison.
module ApiTokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token
  end

  private

  def authenticate_api_token
    expected = ENV["AFIDA_INTERNAL_API_TOKEN"]

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
