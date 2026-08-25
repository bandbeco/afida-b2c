# frozen_string_literal: true

require "test_helper"

# Exercises BotTrafficTrackingMiddleware through the real middleware stack,
# proving placement: it must sit above ActionDispatch::Static (so crawls of
# static files like /llms.txt are seen) and above the exception renderer (so
# crawls of stale URLs are reported with their 404 status).
class BotTrafficTrackingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  GPTBOT_UA = "Mozilla/5.0 AppleWebKit/537.36; compatible; GPTBot/1.2; +https://openai.com/gptbot"
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

  test "tracks a crawler hit on the static llms.txt file" do
    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      get "/llms.txt", headers: { "User-Agent" => GPTBOT_UA }
    end
    assert_response :success

    enqueued = enqueued_jobs.last
    assert_includes enqueued[:args].first["href"], "/llms.txt"
    assert_equal 200, enqueued[:args].first["status_code"]
  end

  test "tracks a crawler 404 on a stale URL" do
    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      get "/this-page-does-not-exist", headers: { "User-Agent" => GPTBOT_UA }
    end
    assert_response :not_found

    enqueued = enqueued_jobs.last
    assert_equal 404, enqueued[:args].first["status_code"]
  end

  test "tracks a crawler hit on robots.txt" do
    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      get "/robots.txt", headers: { "User-Agent" => GPTBOT_UA }
    end
    assert_response :success
  end

  test "does not track a human pageview" do
    assert_no_enqueued_jobs only: DatafastBotTrafficJob do
      get "/", headers: { "User-Agent" => BROWSER_UA }
    end
    assert_response :success
  end
end
