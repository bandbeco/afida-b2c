# frozen_string_literal: true

# Test helper for stubbing Telegram Bot API calls.
#
# Usage in tests:
#   include TelegramTestHelper
#
#   test "sends order notification" do
#     stub_telegram_credentials
#     stub_telegram_send_message
#     TelegramNotifier.notify_new_order(order)
#     assert_telegram_message_sent
#   end
#
module TelegramTestHelper
  TELEGRAM_BOT_TOKEN = "test_bot_token"
  TELEGRAM_CHAT_ID = "-1001234567890"
  TELEGRAM_ENDPOINT = "https://api.telegram.org/bot#{TELEGRAM_BOT_TOKEN}/sendMessage"

  # Stubs a successful sendMessage response
  def stub_telegram_send_message
    stub_request(:post, TELEGRAM_ENDPOINT)
      .to_return(status: 200, body: { ok: true }.to_json, headers: { "Content-Type" => "application/json" })
  end

  # Stubs sendMessage with an error response
  def stub_telegram_error(status: 400, error: "Bad Request")
    stub_request(:post, TELEGRAM_ENDPOINT)
      .to_return(status: status, body: { ok: false, description: error }.to_json)
  end

  # Stubs a network timeout
  def stub_telegram_timeout
    stub_request(:post, TELEGRAM_ENDPOINT).to_timeout
  end

  # Stubs a network error
  def stub_telegram_network_error
    stub_request(:post, TELEGRAM_ENDPOINT).to_raise(HTTP::ConnectionError.new("Connection refused"))
  end

  # Asserts a message was sent (optionally matching text content)
  def assert_telegram_message_sent(text: nil)
    if text
      assert_requested :post, TELEGRAM_ENDPOINT, body: hash_including(text: text)
    else
      assert_requested :post, TELEGRAM_ENDPOINT
    end
  end

  # Asserts no message was sent
  def assert_no_telegram_message_sent
    assert_not_requested :post, TELEGRAM_ENDPOINT
  end

  # Sets up Telegram credentials for testing
  def stub_telegram_credentials(bot_token: TELEGRAM_BOT_TOKEN, chat_id: TELEGRAM_CHAT_ID)
    Rails.application.credentials.stubs(:dig).with(:telegram, :bot_token).returns(bot_token)
    Rails.application.credentials.stubs(:dig).with(:telegram, :chat_id).returns(chat_id)
  end

  # Clears Telegram credentials (simulates unconfigured state)
  def stub_telegram_credentials_missing
    Rails.application.credentials.stubs(:dig).with(:telegram, :bot_token).returns(nil)
    Rails.application.credentials.stubs(:dig).with(:telegram, :chat_id).returns(nil)
  end
end
