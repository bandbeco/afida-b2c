# frozen_string_literal: true

# Explicitly require AWS SDK so rescue_from handlers are always registered
require "aws-sdk-s3"

Rails.application.config.to_prepare do
  # Shared rescue handlers module for both proxy controllers
  module ActiveStorageS3ErrorHandlers
    extend ActiveSupport::Concern

    included do
      # S3 errors are mapped to appropriate HTTP responses instead of 500s
      # BadRequest is mapped to 404 because it indicates a variant processing issue
      # that won't resolve on retry, and exposing S3 config errors to users isn't helpful
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
      if original_error.is_a?(Net::ReadTimeout)
        Rails.logger.error("S3 read timeout: #{original_error.message}")
      else
        Rails.logger.error("S3 network error: #{original_error.class.name}: #{original_error.message}")
      end
      Sentry.capture_exception(error)
      head :service_unavailable
    end
  end

  ActiveStorage::Representations::ProxyController.include(ActiveStorageS3ErrorHandlers)
  ActiveStorage::Blobs::ProxyController.include(ActiveStorageS3ErrorHandlers)
end
