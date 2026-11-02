# frozen_string_literal: true

# Explicitly require the AWS SDK so the error classes exist when a proxy request fails.
require "aws-sdk-s3"

Rails.application.config.to_prepare do
  ActiveStorage::Representations::ProxyController.include(ActiveStorageS3ErrorHandlers)
  ActiveStorage::Blobs::ProxyController.include(ActiveStorageS3ErrorHandlers)
end
