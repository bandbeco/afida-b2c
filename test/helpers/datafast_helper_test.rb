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

  # JavaScript safety tests

  test "datafast_view_item_goal escapes special characters in SKU" do
    @product.stubs(:sku).returns('SKU"with<special>chars')

    result = datafast_view_item_goal(@product)

    # JSON encoding should escape the special chars
    assert_includes result, 'SKU\"with\u003cspecial\u003echars'
  end
end
