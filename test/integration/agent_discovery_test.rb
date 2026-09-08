# frozen_string_literal: true

require "test_helper"

class AgentDiscoveryTest < ActionDispatch::IntegrationTest
  AGENT_RELS = %w[api-catalog service-desc service-doc describedby].freeze

  test "homepage Link header advertises agent discovery relations" do
    get root_path

    assert_response :success
    link = Array(response.headers["Link"]).join(", ")
    AGENT_RELS.each do |rel|
      assert_match(/rel="#{rel}"/, link, "expected Link header to include rel=#{rel}")
    end
    assert_match(%r{/\.well-known/api-catalog}, link)
    assert_match(%r{/openapi\.json}, link)
    assert_match(%r{/\.well-known/mcp/server-card\.json}, link)
  end

  test "HEAD homepage also carries Link headers" do
    head root_path

    assert_response :success
    link = Array(response.headers["Link"]).join(", ")
    assert_match(/rel="api-catalog"/, link)
  end

  test "api-catalog is a RFC 9727 linkset" do
    get "/.well-known/api-catalog"

    assert_response :success
    assert_equal "application/linkset+json", response.media_type
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_nil cookies[:datafast_visitor_id]

    body = JSON.parse(response.body)
    assert body["linkset"].is_a?(Array)
    assert_operator body["linkset"].size, :>=, 1

    catalog = body["linkset"].find { |entry| entry["anchor"]&.end_with?("/api/v1/products") }
    assert catalog, "expected an anchor for the catalog API"
    assert catalog["service-desc"].present?
    assert catalog["service-doc"].present?
    assert catalog["status"].present?
    assert catalog["service-desc"].any? { |l| l["href"]&.end_with?("/openapi.json") }
  end

  test "MCP server card describes the live MCP endpoint" do
    get "/.well-known/mcp/server-card.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    body = JSON.parse(response.body)
    assert_equal "Afida", body.dig("serverInfo", "name")
    assert body.dig("serverInfo", "version").present?
    assert body["url"].end_with?("/mcp")
    assert_equal "streamable-http", body.dig("transport", "type")
    assert_equal true, body.dig("capabilities", "tools")
  end

  test "mcp.json aliases the server card" do
    get "/.well-known/mcp/server-card.json"
    card = JSON.parse(response.body)

    get "/.well-known/mcp.json"
    assert_response :success
    assert_equal card, JSON.parse(response.body)
  end

  test "agent skills index lists shop skills with digests" do
    get "/.well-known/agent-skills/index.json"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "https://schemas.agentskills.io/discovery/0.2.0/schema.json", body["$schema"]
    assert body["skills"].is_a?(Array)
    assert_operator body["skills"].size, :>=, 1

    body["skills"].each do |skill|
      assert skill["name"].present?
      assert_equal "skill-md", skill["type"]
      assert skill["description"].present?
      assert skill["url"].present?
      assert_match(/\Asha256:[0-9a-f]{64}\z/, skill["digest"])

      get skill["url"].sub(%r{\Ahttps?://[^/]+}, "")
      assert_response :success
      digest = Digest::SHA256.hexdigest(response.body)
      assert_equal "sha256:#{digest}", skill["digest"]
    end
  end

  test "ARD capability manifest lists MCP, OpenAPI and skills" do
    get "/.well-known/ai-catalog.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    body = JSON.parse(response.body)
    assert body["specVersion"].present?
    assert body.dig("host", "displayName").present?
    assert body.dig("host", "identifier").present?
    assert body["entries"].is_a?(Array)
    assert_operator body["entries"].size, :>=, 2

    body["entries"].each do |entry|
      assert_match(/\Aurn:air:[^:]+:[^:]+:.+\z/, entry["identifier"])
      assert entry["displayName"].present?
      assert entry["type"].present?
      xor_url_data = entry.key?("url") ^ entry.key?("data")
      assert xor_url_data, "entry #{entry["identifier"]} must have exactly one of url or data"
      queries = entry["representativeQueries"]
      assert queries.is_a?(Array)
      assert_operator queries.size, :>=, 2
      assert_operator queries.size, :<=, 5
    end
  end

  test "OpenAPI document describes the catalog and checkout with MPP payment info" do
    get "/openapi.json"

    assert_response :success
    body = JSON.parse(response.body)
    assert_match(/\A3\./, body["openapi"])
    assert body.dig("info", "title").present?
    paths = body["paths"]
    assert paths["/api/v1/products"]
    assert_equal [], paths["/api/v1/products"]["get"]["security"]
    assert paths["/api/v1/products/{slug}"]
    assert_equal [], paths["/api/v1/products/{slug}"]["get"]["security"]
    checkout = paths["/api/v1/acp/checkout_sessions"]["post"]
    payment = checkout["x-payment-info"]
    assert_equal "session", payment["intent"]
    assert_equal "stripe", payment["method"]
    assert payment["amount"].present?
    assert_equal "GBP", payment["currency"]
  end

  test "auth.md describes agentic registration" do
    get "/auth.md"

    assert_response :success
    assert_match(%r{\Atext/markdown}, response.media_type)
    assert_match(/^# .*auth\.md/i, response.body)
    assert_includes response.body, "You are an agent"
    assert_includes response.body, "agentic registration"
    assert_includes response.body, "register_uri"
    assert_includes response.body, "agent_auth"
    assert_match(/## Step \d+ — Register/, response.body)
    assert_match(/## Step \d+ — Authorize/, response.body)
    assert_match(/## Step \d+ — Exchange/, response.body)
    assert_match(/^## Revocation/i, response.body)
    assert_includes response.body, "/oauth/register"
    assert_includes response.body, "The product catalog is public"
  end

  test "OAuth authorization server metadata is complete" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal request.base_url, body["issuer"]
    assert body["authorization_endpoint"].present?
    assert body["token_endpoint"].present?
    assert body["jwks_uri"].present?
    assert body["grant_types_supported"].is_a?(Array)
    assert body["response_types_supported"].is_a?(Array)
    agent_auth = body["agent_auth"]
    assert agent_auth.is_a?(Hash)
    assert_equal "#{request.base_url}/auth.md", agent_auth["skill"]
    assert_equal "#{request.base_url}/oauth/register", agent_auth["register_uri"]
    assert_includes agent_auth["identity_types_supported"], "anonymous"
    assert_includes agent_auth.dig("anonymous", "credential_types_supported"), "client_secret"
    assert agent_auth.dig("anonymous", "claim_uri").present?
  end

  test "OAuth protected resource metadata identifies the origin" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    body = JSON.parse(response.body)
    resource = URI.parse(body["resource"])
    assert_equal request.host, resource.host
    assert_includes [ "", "/" ], resource.path
    assert_includes body["authorization_servers"], request.base_url
    refute_includes body["scopes_supported"], "catalog.read"
    assert_includes body["bearer_methods_supported"], "header"
  end

  test "UCP profile advertises catalog and checkout" do
    get "/.well-known/ucp"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["protocol_version"].present? || body.dig("ucp", "version").present?
    services = body["services"] || body.dig("ucp", "services")
    assert services.present?
    capabilities = body["capabilities"] || body.dig("ucp", "capabilities")
    assert capabilities.present?
    endpoints = body["endpoints"]
    assert endpoints.present?
  end

  test "ACP discovery document is present" do
    get "/.well-known/acp.json"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "acp", body.dig("protocol", "name")
    assert body.dig("protocol", "version").present?
    assert_match(%r{\Ahttps?://}, body["api_base_url"])
    assert body["transports"].is_a?(Array)
    assert_operator body["transports"].size, :>=, 1
    assert body.dig("capabilities", "services").is_a?(Array)
    assert_operator body.dig("capabilities", "services").size, :>=, 1
  end

  test "robots.txt points at the ARD catalog" do
    get "/robots.txt"

    assert_response :success
    assert_match(%r{^Agentmap: https?://[^ ]+/\.well-known/ai-catalog\.json}m, response.body)
  end

  test "homepage HTML links the ARD catalog" do
    get root_path

    assert_select 'link[rel="ai-catalog"][href="/.well-known/ai-catalog.json"]'
  end

  test "cross-origin preflights are answered for the agent POST endpoints" do
    [ "/mcp", "/oauth/register", "/oauth/token", "/api/v1/acp/checkout_sessions" ].each do |path|
      process :options, path, headers: {
        "HTTP_ORIGIN" => "https://agent.example",
        "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "POST",
        "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "content-type"
      }

      assert_response :no_content, "expected #{path} to answer a preflight"
      assert_equal "*", response.headers["Access-Control-Allow-Origin"]
      assert_includes response.headers["Access-Control-Allow-Methods"], "POST"
      assert_includes response.headers["Access-Control-Allow-Headers"], "Content-Type"
    end
  end

  test "WebMCP script registers storefront tools" do
    source = File.read(Rails.root.join("app/frontend/javascript/webmcp.js"))

    assert_includes source, "registerTool"
    assert_includes source, "search_catalog"
    assert_includes source, "get_product"
    assert_includes source, "add_to_cart"
    assert_includes source, "inputSchema"
    assert_includes source, "renderStreamMessage"
  end
end
