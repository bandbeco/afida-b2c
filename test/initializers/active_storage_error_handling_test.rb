# frozen_string_literal: true

require "test_helper"

class ActiveStorageErrorHandlingTest < ActiveSupport::TestCase
  setup do
    @controller = ActiveStorage::Representations::ProxyController.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new
  end

  test "handles S3 Http503Error with 503 response" do
    error = Aws::S3::Errors::Http503Error.new(nil, "Service Unavailable")

    Rails.logger.expects(:warn).with(regexp_matches(/S3 service unavailable/))

    @controller.send(:handle_s3_service_unavailable, error)

    assert_equal 503, @controller.response.status
  end

  test "handles S3 BadRequest with 404 response" do
    error = Aws::S3::Errors::BadRequest.new(nil, "Bad Request")

    Rails.logger.expects(:warn).with(regexp_matches(/S3 bad request/))

    @controller.send(:handle_s3_bad_request, error)

    assert_equal 404, @controller.response.status
  end

  test "handles Net::ReadTimeout with 503 response and Sentry capture" do
    error = Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new)

    Rails.logger.expects(:error).with(regexp_matches(/S3 read timeout/))
    Sentry.expects(:capture_exception).with(error) if defined?(Sentry)

    @controller.send(:handle_s3_network_error, error)

    assert_equal 503, @controller.response.status
  end

  test "handles other NetworkingError with 503 response and Sentry capture" do
    error = Seahorse::Client::NetworkingError.new(StandardError.new("Network issue"))

    Rails.logger.expects(:error).with(regexp_matches(/S3 network error/))
    Sentry.expects(:capture_exception).with(error) if defined?(Sentry)

    @controller.send(:handle_s3_network_error, error)

    assert_equal 503, @controller.response.status
  end
end
