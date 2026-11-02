# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Only add error handlers if AWS SDK is loaded (production with S3 storage)
  if defined?(Aws::S3::Errors)
    ActiveStorage::Representations::ProxyController.class_eval do
      rescue_from Aws::S3::Errors::Http503Error, with: :handle_s3_service_unavailable
      rescue_from Aws::S3::Errors::BadRequest, with: :handle_s3_bad_request
      rescue_from Seahorse::Client::NetworkingError, with: :handle_s3_network_error

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
  end
end
