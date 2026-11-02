# frozen_string_literal: true

# Explicitly require AWS SDK so rescue_from handlers are always registered
require "aws-sdk-s3"

Rails.application.config.to_prepare do
  ActiveStorage::Representations::ProxyController.class_eval do
    # S3 errors are mapped to appropriate HTTP responses instead of 500s
    # BadRequest is mapped to 404 because it indicates a variant processing issue
    # that won't resolve on retry, and exposing S3 config errors to users isn't helpful
    rescue_from "Aws::S3::Errors::Http503Error", with: :handle_s3_service_unavailable
    rescue_from "Aws::S3::Errors::BadRequest", with: :handle_s3_bad_request
    rescue_from "Seahorse::Client::NetworkingError", with: :handle_s3_network_error

    private

    def handle_s3_service_unavailable(error)
      Rails.logger.warn("S3 service unavailable for representation: #{error.message}")
      head :service_unavailable
    end

    def handle_s3_bad_request(error)
      Rails.logger.error("S3 bad request for representation: #{error.message}")
      Sentry.capture_exception(error)
      head :not_found
    end

    def handle_s3_network_error(error)
      original_error = error.original_error
      if original_error.is_a?(Net::ReadTimeout)
        Rails.logger.error("S3 read timeout for representation: #{original_error.message}")
      else
        Rails.logger.error("S3 network error for representation: #{original_error.class.name}: #{original_error.message}")
      end
      Sentry.capture_exception(error)
      head :service_unavailable
    end
  end

  # Also handle S3 errors on blob proxy controller
  ActiveStorage::Blobs::ProxyController.class_eval do
    rescue_from "Aws::S3::Errors::Http503Error", with: :handle_s3_service_unavailable
    rescue_from "Aws::S3::Errors::BadRequest", with: :handle_s3_bad_request
    rescue_from "Seahorse::Client::NetworkingError", with: :handle_s3_network_error

    private

    def handle_s3_service_unavailable(error)
      Rails.logger.warn("S3 service unavailable for blob: #{error.message}")
      head :service_unavailable
    end

    def handle_s3_bad_request(error)
      Rails.logger.error("S3 bad request for blob: #{error.message}")
      Sentry.capture_exception(error)
      head :not_found
    end

    def handle_s3_network_error(error)
      original_error = error.original_error
      if original_error.is_a?(Net::ReadTimeout)
        Rails.logger.error("S3 read timeout for blob: #{original_error.message}")
      else
        Rails.logger.error("S3 network error for blob: #{original_error.class.name}: #{original_error.message}")
      end
      Sentry.capture_exception(error)
      head :service_unavailable
    end
  end
end
