# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class MargotNotifierTest < ActiveSupport::TestCase
  GATEWAY_URL = "https://margot.example.com"
  HOOK_TOKEN = "test_hook_token"
  CHAT_ID = "-1001234567890"
  HOOK_ENDPOINT = "#{GATEWAY_URL}/hooks/agent"

  setup do
    @order = orders(:one)
    stub_margot_credentials
  end

  test "posts an agent hook request and returns true on success" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true, runId: "r1" }.to_json)

    assert MargotNotifier.request_research(@order)
    assert_requested :post, HOOK_ENDPOINT
  end

  test "authenticates with the hook token as a bearer token" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true }.to_json)

    MargotNotifier.request_research(@order)

    assert_requested :post, HOOK_ENDPOINT, headers: { "Authorization" => "Bearer #{HOOK_TOKEN}" }
  end

  test "targets the Telegram group and requests delivery" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true }.to_json)

    MargotNotifier.request_research(@order)

    assert_requested :post, HOOK_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["channel"] == "telegram" && body["to"] == CHAT_ID && body["deliver"] == true
    end
  end

  test "targets the afida agent and leaves session management to Margot's config" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true }.to_json)

    MargotNotifier.request_research(@order)

    assert_requested :post, HOOK_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["agentId"] == "afida" && !body.key?("sessionMode") && !body.key?("sessionKey")
    end
  end

  test "prompt includes the order details Margot needs" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true }.to_json)

    MargotNotifier.request_research(@order)

    assert_requested :post, HOOK_ENDPOINT do |req|
      message = JSON.parse(req.body)["message"]
      message.include?(@order.display_number) &&
        message.include?(@order.email) &&
        message.include?(@order.shipping_name) &&
        message.include?(@order.full_shipping_address)
    end
  end

  test "returns false and sends nothing when credentials are missing" do
    stub_margot_credentials(gateway_url: nil, hook_token: nil)
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 200, body: { ok: true }.to_json)

    assert_not MargotNotifier.request_research(@order)
    assert_not_requested :post, HOOK_ENDPOINT
  end

  test "returns false on an API error response" do
    stub_request(:post, HOOK_ENDPOINT).to_return(status: 401, body: { ok: false }.to_json)

    assert_not MargotNotifier.request_research(@order)
  end

  test "returns false and does not raise on timeout" do
    stub_request(:post, HOOK_ENDPOINT).to_timeout

    assert_nothing_raised do
      assert_not MargotNotifier.request_research(@order)
    end
  end

  test "returns false and does not raise on a network error" do
    stub_request(:post, HOOK_ENDPOINT).to_raise(HTTP::ConnectionError.new("Connection refused"))

    assert_nothing_raised do
      assert_not MargotNotifier.request_research(@order)
    end
  end

  private

  def stub_margot_credentials(gateway_url: GATEWAY_URL, hook_token: HOOK_TOKEN, chat_id: CHAT_ID)
    MargotNotifier.any_instance.stubs(:gateway_url).returns(gateway_url)
    MargotNotifier.any_instance.stubs(:hook_token).returns(hook_token)
    MargotNotifier.any_instance.stubs(:chat_id).returns(chat_id)
  end
end
