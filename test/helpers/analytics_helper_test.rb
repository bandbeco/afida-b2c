# frozen_string_literal: true

require "test_helper"

class AnalyticsHelperTest < ActionView::TestCase
  include AnalyticsHelper

  setup do
    @product = products(:one)
    @cart = carts(:one)
    @cart_item = cart_items(:one)
    @order = orders(:one)
    @order_item = order_items(:one)
  end

  # GA4 Item formatting tests

  test "ga4_item returns properly formatted item hash" do
    item = ga4_item(@product)

    assert_equal @product.sku, item[:item_id]
    assert_equal @product.generated_title, item[:item_name]
    assert_equal @product.price.to_f, item[:price]
    assert_equal 1, item[:quantity]
  end

  test "ga4_item with custom quantity" do
    item = ga4_item(@product, quantity: 5)
    assert_equal 5, item[:quantity]
  end

  test "ga4_cart_item returns properly formatted item hash from cart item" do
    item = ga4_cart_item(@cart_item)

    assert_equal @cart_item.product.sku, item[:item_id]
    assert_equal @cart_item.product.generated_title, item[:item_name]
    assert_equal @cart_item.quantity, item[:quantity]
  end

  test "ga4_order_item returns properly formatted item hash from order item" do
    item = ga4_order_item(@order_item)

    assert_equal @order_item.product_sku, item[:item_id]
    assert_equal @order_item.product.generated_title, item[:item_name]
    assert_equal @order_item.quantity, item[:quantity]
  end

  # GTM disabled tests

  test "ecommerce events return empty string when GTM disabled" do
    # GTM is disabled in test environment by default
    Rails.application.config.x.gtm_container_id = nil

    assert_equal "", ecommerce_view_item_event(@product)
    assert_equal "", ecommerce_add_to_cart_event(@product, quantity: 1, value: 10.0)
    assert_equal "", ecommerce_view_cart_event(@cart)
    assert_equal "", ecommerce_begin_checkout_event(@cart)
    assert_equal "", ecommerce_purchase_event(@order)
  end

  # GTM enabled tests

  test "ecommerce_view_item_event generates valid JavaScript when GTM enabled" do
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"

    result = ecommerce_view_item_event(@product)

    assert_includes result, "dataLayer.push({ ecommerce: null })"
    assert_includes result, '"event":"view_item"'
    assert_includes result, '"currency":"GBP"'
    assert_includes result, @product.sku

    Rails.application.config.x.gtm_container_id = nil
  end

  test "ecommerce_add_to_cart_event generates valid JavaScript when GTM enabled" do
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"

    result = ecommerce_add_to_cart_event(@product, quantity: 3, value: 30.0)

    assert_includes result, '"event":"add_to_cart"'
    assert_includes result, '"value":30.0'
    assert_includes result, '"quantity":3'

    Rails.application.config.x.gtm_container_id = nil
  end

  test "ecommerce_purchase_event includes transaction details" do
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"

    result = ecommerce_purchase_event(@order)

    assert_includes result, '"event":"purchase"'
    assert_includes result, '"transaction_id"'
    assert_includes result, @order.order_number
    assert_includes result, '"tax"'
    assert_includes result, '"shipping"'

    Rails.application.config.x.gtm_container_id = nil
  end

  test "ga4_cart_items_json returns valid JSON" do
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"

    result = ga4_cart_items_json(@cart)

    parsed = JSON.parse(result)
    assert_kind_of Array, parsed
    assert parsed.length > 0

    Rails.application.config.x.gtm_container_id = nil
  end
end
