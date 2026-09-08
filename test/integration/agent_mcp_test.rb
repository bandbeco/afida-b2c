# frozen_string_literal: true

require "test_helper"

class AgentMcpTest < ActionDispatch::IntegrationTest
  test "initialize returns server capabilities" do
    post "/mcp", params: {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      }
    }, as: :json

    assert_response :success
    assert_nil response.headers["WWW-Authenticate"]
    body = response.parsed_body
    assert_equal "2.0", body["jsonrpc"]
    assert_equal 1, body["id"]
    assert_equal "Afida", body.dig("result", "serverInfo", "name")
    assert body.dig("result", "capabilities", "tools")
  end

  test "HEAD is answered like the GET server card, not routed into the JSON-RPC branch" do
    get "/mcp"
    card_etag = response.headers["ETag"]

    head "/mcp"

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal card_etag, response.headers["ETag"]
  end

  test "tools/list includes catalog tools" do
    post "/mcp", params: { jsonrpc: "2.0", id: 2, method: "tools/list" }, as: :json

    assert_response :success
    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "search_products"
    assert_includes names, "get_product"
    assert_includes names, "list_categories"
  end

  test "search_products returns matching catalog rows" do
    post "/mcp", params: {
      jsonrpc: "2.0",
      id: 3,
      method: "tools/call",
      params: { name: "search_products", arguments: { query: products(:one).sku } }
    }, as: :json

    assert_response :success
    text = response.parsed_body.dig("result", "content", 0, "text")
    payload = JSON.parse(text)
    slugs = payload["data"].map { |row| row["slug"] }
    assert_includes slugs, products(:one).slug
  end

  test "get_product returns a single product" do
    post "/mcp", params: {
      jsonrpc: "2.0",
      id: 4,
      method: "tools/call",
      params: { name: "get_product", arguments: { slug: products(:one).slug } }
    }, as: :json

    assert_response :success
    payload = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))
    assert_equal products(:one).slug, payload.dig("data", "slug")
  end
end
