# frozen_string_literal: true

require "test_helper"

class DatafastHelperTest < ActionView::TestCase
  include DatafastHelper

  setup do
    @product = products(:one)
    # Stub credentials to enable DataFast
    Rails.application.credentials.stubs(:dig).with(:datafast, :api_key).returns("df_test_key")
  end

  # view_item tests

  test "datafast_view_item_goal generates JavaScript with product data" do
    result = datafast_view_item_goal(@product)

    assert_includes result, "window.datafast?"
    assert_includes result, "view_item"
    assert_includes result, @product.id.to_s
    assert_includes result, @product.sku
  end

  test "datafast_view_item_goal returns empty string when disabled" do
    Rails.application.credentials.stubs(:dig).with(:datafast, :api_key).returns(nil)

    result = datafast_view_item_goal(@product)

    assert_equal "", result
  end

  test "datafast_view_item_goal is html_safe" do
    result = datafast_view_item_goal(@product)

    assert result.html_safe?
  end

  # view_cart tests

  test "datafast_view_cart_goal generates JavaScript with cart data" do
    cart = carts(:one)
    # Ensure cart has items for the test
    cart.stubs(:cart_items).returns(stub(count: 3))
    cart.stubs(:subtotal_amount).returns(BigDecimal("99.99"))

    result = datafast_view_cart_goal(cart)

    assert_includes result, "window.datafast?"
    assert_includes result, "view_cart"
    assert_includes result, '"item_count":"3"'
    assert_includes result, '"subtotal":"99.99"'
  end

  test "datafast_view_cart_goal returns empty string when disabled" do
    Rails.application.credentials.stubs(:dig).with(:datafast, :api_key).returns(nil)
    cart = carts(:one)

    result = datafast_view_cart_goal(cart)

    assert_equal "", result
  end

  test "datafast_view_cart_goal handles empty cart" do
    cart = carts(:one)
    cart.stubs(:cart_items).returns(stub(count: 0))
    cart.stubs(:subtotal_amount).returns(BigDecimal("0"))

    result = datafast_view_cart_goal(cart)

    assert_includes result, '"item_count":"0"'
    assert_includes result, '"subtotal":"0.0"'
  end

  # JavaScript safety tests

  test "datafast_view_item_goal escapes special characters in SKU" do
    @product.stubs(:sku).returns('SKU"with<special>chars')

    result = datafast_view_item_goal(@product)

    # JSON encoding should escape the special chars
    assert_includes result, 'SKU\"with\u003cspecial\u003echars'
  end
end
