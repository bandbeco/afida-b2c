# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class DatafastBotTrafficServiceTest < ActiveSupport::TestCase
  include DatafastTestHelper

  setup do
    stub_datafast_bot_traffic_token(nil)
    @href = "https://afida.com/paper-cups"
    @user_agent = "Mozilla/5.0 AppleWebKit/537.36; compatible; GPTBot/1.2"
  end

  test "tracks an AI crawl with the required payload" do
    stub_datafast_ai_crawl_create

    result = DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)

    assert result
    assert_requested :post, DATAFAST_AI_CRAWLS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["websiteId"] == Datafast::WEBSITE_ID &&
        body["domain"] == Datafast::DOMAIN &&
        body["href"] == @href &&
        body.dig("ai", "userAgent") == @user_agent &&
        body.dig("ai", "source") == "server_middleware"
    end
  end

  test "includes ip and statusCode when provided" do
    stub_datafast_ai_crawl_create

    DatafastBotTrafficService.track(href: @href, user_agent: @user_agent, ip: "203.0.113.10", status_code: 404)

    assert_requested :post, DATAFAST_AI_CRAWLS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body.dig("ai", "ip") == "203.0.113.10" && body.dig("ai", "statusCode") == 404
    end
  end

  test "omits ip and statusCode when not provided" do
    stub_datafast_ai_crawl_create

    DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)

    assert_requested :post, DATAFAST_AI_CRAWLS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      !body["ai"].key?("ip") && !body["ai"].key?("statusCode")
    end
  end

  test "sends Authorization header when bot traffic token is configured" do
    stub_datafast_bot_traffic_token("dfbot_test_token")
    stub_datafast_ai_crawl_create

    DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)

    assert_requested :post, DATAFAST_AI_CRAWLS_ENDPOINT,
                     headers: { "Authorization" => "Bearer dfbot_test_token" }
  end

  test "sends no Authorization header when token is not configured" do
    stub_datafast_ai_crawl_create

    DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)

    assert_requested(:post, DATAFAST_AI_CRAWLS_ENDPOINT) do |req|
      req.headers["Authorization"].nil?
    end
  end

  test "returns false when href or user agent is blank" do
    stub_datafast_ai_crawl_create

    assert_not DatafastBotTrafficService.track(href: "", user_agent: @user_agent)
    assert_not DatafastBotTrafficService.track(href: @href, user_agent: nil)

    assert_no_datafast_ai_crawls_tracked
  end

  test "returns false on API error" do
    stub_datafast_ai_crawl_error(status: 429, error: "Rate limited")

    assert_not DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)
  end

  test "returns false on timeout" do
    stub_datafast_ai_crawl_timeout

    assert_not DatafastBotTrafficService.track(href: @href, user_agent: @user_agent)
  end
end
