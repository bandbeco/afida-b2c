# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class DatafastServiceTest < ActiveSupport::TestCase
  include DatafastTestHelper

  setup do
    @visitor_id = "df_visitor_abc123"
    stub_datafast_credentials
  end

  test "tracks goal successfully" do
    stub_datafast_goal_create

    result = DatafastService.track("add_to_cart", visitor_id: @visitor_id)

    assert result
    assert_datafast_goal_tracked("add_to_cart")
  end

  test "includes metadata in request" do
    stub_datafast_goal_create
    metadata = { product_id: "123", quantity: "2" }

    DatafastService.track("add_to_cart", visitor_id: @visitor_id, metadata: metadata)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["metadata"]["product_id"] == "123" && body["metadata"]["quantity"] == "2"
    end
  end

  test "returns false when visitor_id is blank" do
    stub_datafast_goal_create

    assert_not DatafastService.track("add_to_cart", visitor_id: nil)
    assert_not DatafastService.track("add_to_cart", visitor_id: "")

    assert_no_datafast_goals_tracked
  end

  test "returns false when API key not configured" do
    stub_datafast_credentials_missing
    stub_datafast_goal_create

    result = DatafastService.track("add_to_cart", visitor_id: @visitor_id)

    assert_not result
    assert_no_datafast_goals_tracked
  end

  test "handles API error gracefully" do
    stub_datafast_goal_error(status: 500, error: "Internal Server Error")

    result = DatafastService.track("add_to_cart", visitor_id: @visitor_id)

    assert_not result
  end

  test "handles network timeout gracefully" do
    stub_datafast_timeout

    result = DatafastService.track("add_to_cart", visitor_id: @visitor_id)

    assert_not result
  end

  test "handles network error gracefully" do
    stub_datafast_network_error

    result = DatafastService.track("add_to_cart", visitor_id: @visitor_id)

    assert_not result
  end

  test "truncates metadata to 10 keys" do
    stub_datafast_goal_create
    # Create metadata with 15 keys
    metadata = (1..15).map { |i| [ "key_#{i}".to_sym, "value_#{i}" ] }.to_h

    DatafastService.track("test", visitor_id: @visitor_id, metadata: metadata)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["metadata"].keys.count == 10
    end
  end

  test "sanitizes goal name to lowercase with allowed characters" do
    stub_datafast_goal_create

    DatafastService.track("Add To Cart!", visitor_id: @visitor_id)

    assert_datafast_goal_tracked("add_to_cart_")
  end

  test "truncates goal name to 64 characters" do
    stub_datafast_goal_create
    long_name = "a" * 100

    DatafastService.track(long_name, visitor_id: @visitor_id)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["name"].length == 64
    end
  end

  test "sanitizes metadata keys" do
    stub_datafast_goal_create
    metadata = { "Product ID" => "123", "Special!Key" => "value" }

    DatafastService.track("test", visitor_id: @visitor_id, metadata: metadata)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["metadata"].keys.include?("product_id") && body["metadata"].keys.include?("special_key")
    end
  end

  test "converts metadata values to strings" do
    stub_datafast_goal_create
    metadata = { count: 42, price: 19.99, active: true }

    DatafastService.track("test", visitor_id: @visitor_id, metadata: metadata)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["metadata"]["count"] == "42" &&
        body["metadata"]["price"] == "19.99" &&
        body["metadata"]["active"] == "true"
    end
  end

  test "truncates metadata values to 255 characters" do
    stub_datafast_goal_create
    long_value = "x" * 300
    metadata = { description: long_value }

    DatafastService.track("test", visitor_id: @visitor_id, metadata: metadata)

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      body["metadata"]["description"].length == 255
    end
  end

  test "omits metadata key when metadata is empty" do
    stub_datafast_goal_create

    DatafastService.track("test", visitor_id: @visitor_id, metadata: {})

    assert_requested :post, DatafastService::ENDPOINT do |req|
      body = JSON.parse(req.body)
      !body.key?("metadata")
    end
  end
end
