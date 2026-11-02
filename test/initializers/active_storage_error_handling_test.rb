# frozen_string_literal: true

require "test_helper"

class ActiveStorageErrorHandlingTest < ActiveSupport::TestCase
  test "rescue_from handlers are registered on Representations::ProxyController" do
    handlers = ActiveStorage::Representations::ProxyController.rescue_handlers

    assert handlers.any? { |h| h.first == "Aws::S3::Errors::Http503Error" },
           "Http503Error handler not registered"
    assert handlers.any? { |h| h.first == "Aws::S3::Errors::BadRequest" },
           "BadRequest handler not registered"
    assert handlers.any? { |h| h.first == "Seahorse::Client::NetworkingError" },
           "NetworkingError handler not registered"
  end

  test "rescue_from handlers are registered on Blobs::ProxyController" do
    handlers = ActiveStorage::Blobs::ProxyController.rescue_handlers

    assert handlers.any? { |h| h.first == "Aws::S3::Errors::Http503Error" },
           "Http503Error handler not registered on Blobs::ProxyController"
    assert handlers.any? { |h| h.first == "Aws::S3::Errors::BadRequest" },
           "BadRequest handler not registered on Blobs::ProxyController"
    assert handlers.any? { |h| h.first == "Seahorse::Client::NetworkingError" },
           "NetworkingError handler not registered on Blobs::ProxyController"
  end

  test "handles S3 Http503Error with 503 response" do
    controller = ActiveStorage::Representations::ProxyController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    error = Aws::S3::Errors::Http503Error.new(nil, "Service Unavailable")

    Rails.logger.expects(:warn).with(regexp_matches(/S3 service unavailable/))
    controller.expects(:head).with(:service_unavailable)

    controller.send(:handle_s3_service_unavailable, error)
  end

  test "handles S3 BadRequest with 404 response and Sentry report" do
    controller = ActiveStorage::Representations::ProxyController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    error = Aws::S3::Errors::BadRequest.new(nil, "Bad Request")

    Rails.logger.expects(:error).with(regexp_matches(/S3 bad request/))
    Sentry.expects(:capture_exception).with(error)
    controller.expects(:head).with(:not_found)

    controller.send(:handle_s3_bad_request, error)
  end

  test "handles Net::ReadTimeout with 503 response and Sentry capture" do
    controller = ActiveStorage::Representations::ProxyController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    original_error = Net::ReadTimeout.new
    error = Seahorse::Client::NetworkingError.new(original_error)

    Rails.logger.expects(:error).with(regexp_matches(/S3 read timeout/))
    Sentry.expects(:capture_exception).with(error)
    controller.expects(:head).with(:service_unavailable)

    controller.send(:handle_s3_network_error, error)
  end

  test "handles other NetworkingError with 503 response and Sentry capture" do
    controller = ActiveStorage::Representations::ProxyController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    original_error = StandardError.new("Network issue")
    error = Seahorse::Client::NetworkingError.new(original_error)

    Rails.logger.expects(:error).with(regexp_matches(/S3 network error/))
    Sentry.expects(:capture_exception).with(error)
    controller.expects(:head).with(:service_unavailable)

    controller.send(:handle_s3_network_error, error)
  end

  test "handles NetworkingError when original_error is nil" do
    controller = ActiveStorage::Representations::ProxyController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    error = Object.new
    error.define_singleton_method(:original_error) { nil }

    Rails.logger.expects(:error).with(regexp_matches(/S3 network error/))
    Sentry.expects(:capture_exception).with(error)
    controller.expects(:head).with(:service_unavailable)

    controller.send(:handle_s3_network_error, error)
  end

  test "standard retry mode caps attempts with max_attempts, not retry_limit" do
    client = Aws::S3::Client.new(
      stub_responses: true,
      region: "us-east-1",
      access_key_id: "test",
      secret_access_key: "secret",
      retry_mode: "standard",
      max_attempts: 3,
      retry_limit: 9
    )

    assert_equal "standard", client.config.retry_mode
    assert_equal 3, client.config.max_attempts
    assert_equal 9, client.config.retry_limit
  end
end

class ActiveStorageProxyRequestTest < ActionDispatch::IntegrationTest
  test "blob proxy show returns 503 when S3 raises Http503Error" do
    blob = upload_blob
    error = Aws::S3::Errors::Http503Error.new(nil, "Service Unavailable")
    ActiveStorage::Blobs::ProxyController.any_instance.stubs(:send_blob_stream).raises(error)

    get rails_storage_proxy_path(blob)

    assert_response :service_unavailable
  end

  test "blob proxy show returns 404 when S3 raises BadRequest" do
    blob = upload_blob
    error = Aws::S3::Errors::BadRequest.new(nil, "Bad Request")
    ActiveStorage::Blobs::ProxyController.any_instance.stubs(:send_blob_stream).raises(error)

    get rails_storage_proxy_path(blob)

    assert_response :not_found
  end

  private

  def upload_blob
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("proxy-body"),
      filename: "proxy.txt",
      content_type: "text/plain"
    )
  end
end
