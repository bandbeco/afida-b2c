# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class Ga4MeasurementProtocolServiceTest < ActiveSupport::TestCase
  GA4_ENDPOINT = "https://www.google-analytics.com/mp/collect"

  setup do
    @order = orders(:one)
    stub_ga4_credentials
    stub_production_environment
  end

  test "does not send event in non-production environment" do
    Rails.env.stubs(:production?).returns(false)

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
    assert_not_requested :post, /#{GA4_ENDPOINT}/
  end

  test "does not send event when measurement_id is missing" do
    Rails.application.credentials.stubs(:dig).with(:ga4, :measurement_id).returns(nil)

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
    assert_not_requested :post, /#{GA4_ENDPOINT}/
  end

  test "does not send event when api_secret is missing" do
    Rails.application.credentials.stubs(:dig).with(:ga4, :api_secret).returns(nil)

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
    assert_not_requested :post, /#{GA4_ENDPOINT}/
  end

  test "sends purchase event to GA4 Measurement Protocol" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_return(status: 204)

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert result
    assert_requested :post, "#{GA4_ENDPOINT}?measurement_id=G-TEST123&api_secret=test_secret" do |req|
      body = JSON.parse(req.body)
      event = body["events"].first

      body["client_id"].present? &&
        event["name"] == "purchase" &&
        event["params"]["transaction_id"] == @order.order_number &&
        event["params"]["value"] == @order.total_amount.to_f &&
        event["params"]["tax"] == @order.vat_amount.to_f &&
        event["params"]["shipping"] == @order.shipping_amount.to_f &&
        event["params"]["currency"] == "GBP" &&
        event["params"]["items"].is_a?(Array)
    end
  end

  test "includes coupon and discount when order has a discount" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_return(status: 204)
    @order.update!(discount_amount: 5.0, discount_code: "WELCOME5")

    Ga4MeasurementProtocolService.track_purchase(@order)

    assert_requested :post, /#{GA4_ENDPOINT}/ do |req|
      body = JSON.parse(req.body)
      params = body["events"].first["params"]
      params["coupon"] == "WELCOME5" && params["discount"] == 5.0
    end
  end

  test "omits coupon and discount when order has no discount" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_return(status: 204)

    Ga4MeasurementProtocolService.track_purchase(@order)

    assert_requested :post, /#{GA4_ENDPOINT}/ do |req|
      body = JSON.parse(req.body)
      params = body["events"].first["params"]
      !params.key?("coupon") && !params.key?("discount")
    end
  end

  test "returns false on API error response" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_return(status: 500, body: "Internal Server Error")

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
  end

  test "handles network timeout gracefully" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_timeout

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
  end

  test "handles network connection error gracefully" do
    stub_request(:post, /#{GA4_ENDPOINT}/).to_raise(SocketError.new("getaddrinfo: Name or service not known"))

    result = Ga4MeasurementProtocolService.track_purchase(@order)

    assert_not result
  end

  private

  def stub_ga4_credentials
    Rails.application.credentials.stubs(:dig).with(:ga4, :measurement_id).returns("G-TEST123")
    Rails.application.credentials.stubs(:dig).with(:ga4, :api_secret).returns("test_secret")
  end

  def stub_production_environment
    Rails.env.stubs(:production?).returns(true)
  end
end
