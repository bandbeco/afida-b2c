# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class TelegramNotifierTest < ActiveSupport::TestCase
  include TelegramTestHelper
  include ActionView::Helpers::NumberHelper

  setup do
    @order = orders(:one)
    stub_telegram_credentials
  end

  test "posts a sendMessage request and returns true on success" do
    stub_telegram_send_message

    assert TelegramNotifier.notify_new_order(@order)
    assert_telegram_message_sent
  end

  test "sends to the configured chat id" do
    stub_telegram_send_message

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT, body: hash_including(chat_id: TELEGRAM_CHAT_ID)
  end

  test "message includes order number, total and admin link" do
    stub_telegram_send_message

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      text = JSON.parse(req.body)["text"]
      text.include?(@order.display_number) &&
        text.include?(number_to_currency(@order.total_amount, unit: "£")) &&
        text.include?("/admin/orders/#{@order.id}")
    end
  end

  test "message reports line-item and unit counts" do
    stub_telegram_send_message
    @order.order_items.destroy_all
    @order.order_items.create!(product: products(:one), product_name: "Cups", product_sku: "C1", price: 10, quantity: 3, line_total: 30)
    @order.order_items.create!(product: products(:two), product_name: "Lids", product_sku: "L1", price: 5, quantity: 4, line_total: 20)

    TelegramNotifier.notify_new_order(@order.reload)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      JSON.parse(req.body)["text"].include?("2 line items / 7 units")
    end
  end

  test "message includes each line item with quantity and product name" do
    stub_telegram_send_message

    TelegramNotifier.notify_new_order(@order)

    item = @order.order_items.first
    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      text = JSON.parse(req.body)["text"]
      text.include?(item.product_name) && text.include?(item.quantity.to_s)
    end
  end

  test "returns false and sends nothing when credentials are missing" do
    stub_telegram_credentials_missing
    stub_telegram_send_message

    assert_not TelegramNotifier.notify_new_order(@order)
    assert_no_telegram_message_sent
  end

  test "returns false on an API error response" do
    stub_telegram_error(status: 500)

    assert_not TelegramNotifier.notify_new_order(@order)
  end

  test "returns false and does not raise on timeout" do
    stub_telegram_timeout

    assert_nothing_raised do
      assert_not TelegramNotifier.notify_new_order(@order)
    end
  end

  test "returns false and does not raise on a network error" do
    stub_telegram_network_error

    assert_nothing_raised do
      assert_not TelegramNotifier.notify_new_order(@order)
    end
  end

  test "HTML-escapes interpolated order data" do
    stub_telegram_send_message
    @order.order_items.first.update!(product_name: "Cups <b>& Lids</b>")

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      text = JSON.parse(req.body)["text"]
      text.include?("Cups &lt;b&gt;&amp; Lids&lt;/b&gt;") && !text.include?("Cups <b>& Lids</b>")
    end
  end

  test "truncates messages longer than the Telegram limit" do
    stub_telegram_send_message
    item = @order.order_items.first
    item.update!(product_name: "X" * 5000)

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      JSON.parse(req.body)["text"].length <= TelegramNotifier::MAX_MESSAGE_LENGTH
    end
  end

  test "truncation never cuts an HTML entity in half" do
    stub_telegram_send_message
    item = @order.order_items.first
    item.update!(product_name: "&" * 3000)

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      text = JSON.parse(req.body)["text"]
      text.length <= TelegramNotifier::MAX_MESSAGE_LENGTH && !text.match?(/&[a-zA-Z#0-9]*\z/)
    end
  end

  test "caps the number of item lines and reports the remainder" do
    stub_telegram_send_message
    @order.order_items.destroy_all
    35.times do |i|
      @order.order_items.create!(product: products(:one), product_name: "Item #{i}", product_sku: "SKU#{i}", price: 1, quantity: 1, line_total: 1)
    end

    TelegramNotifier.notify_new_order(@order.reload)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      text = JSON.parse(req.body)["text"]
      item_lines = text.lines.count { |line| line.start_with?("•") }
      text.include?("35 line items") &&
        item_lines == TelegramNotifier::MAX_ITEM_LINES &&
        text.include?("and #{35 - TelegramNotifier::MAX_ITEM_LINES} more")
    end
  end

  test "disables link previews" do
    stub_telegram_send_message

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      JSON.parse(req.body).dig("link_preview_options", "is_disabled") == true
    end
  end

  test "sends a valid message for an order with no items" do
    stub_telegram_send_message
    @order.order_items.destroy_all

    assert TelegramNotifier.notify_new_order(@order.reload)
    assert_telegram_message_sent
  end

  test "falls back to email when shipping name is blank" do
    stub_telegram_send_message
    @order.update_columns(shipping_name: "")

    TelegramNotifier.notify_new_order(@order)

    assert_requested :post, TELEGRAM_ENDPOINT do |req|
      JSON.parse(req.body)["text"].include?(@order.email)
    end
  end
end
