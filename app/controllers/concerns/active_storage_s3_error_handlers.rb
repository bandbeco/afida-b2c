# frozen_string_literal: true

# Maps S3 failures from the Active Storage proxy controllers onto client
# statuses instead of 500s. Included from config/initializers/active_storage_error_handling.rb.
module ActiveStorageS3ErrorHandlers
  extend ActiveSupport::Concern

  included do
    # BadRequest maps to 404 because variant and key errors will not succeed on
    # retry, and the raw S3 message should not be shown to visitors.
    # Http503Error is logged only, so an outage does not flood Sentry.
    # NetworkingError and BadRequest are reported.
    rescue_from "Aws::S3::Errors::Http503Error", with: :handle_s3_service_unavailable
    rescue_from "Aws::S3::Errors::BadRequest", with: :handle_s3_bad_request
    rescue_from "Seahorse::Client::NetworkingError", with: :handle_s3_network_error
  end

  private

  def handle_s3_service_unavailable(error)
    Rails.logger.warn("S3 service unavailable: #{error.message}")
    head :service_unavailable
  end

  def handle_s3_bad_request(error)
    Rails.logger.error("S3 bad request: #{error.message}")
    Sentry.capture_exception(error)
    head :not_found
  end

  def handle_s3_network_error(error)
    original_error = error.original_error
    if original_error&.is_a?(Net::ReadTimeout)
      Rails.logger.error("S3 read timeout: #{original_error.message}")
    else
      Rails.logger.error("S3 network error: #{original_error&.class&.name}: #{original_error&.message}")
    end
    Sentry.capture_exception(error)
    head :service_unavailable
  end
end
