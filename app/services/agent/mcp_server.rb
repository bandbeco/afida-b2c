# frozen_string_literal: true

module Agent
  class McpServer
    PROTOCOL_VERSION = "2025-03-26"

    def initialize(base_url:)
      @catalog = Agent::Catalog.new(base_url: base_url)
    end

    def handle(message)
      return rpc_error(nil, -32600, "Invalid Request") unless message.is_a?(Hash)

      method = message["method"]
      id = message["id"]
      params = message["params"] || {}

      return notification_ack if method.to_s.start_with?("notifications/") && id.nil?

      case method
      when "initialize"
        rpc_result(id, initialize_result)
      when "ping"
        rpc_result(id, {})
      when "tools/list"
        rpc_result(id, { "tools" => tools })
      when "tools/call"
        call_tool(id, params)
      else
        rpc_error(id, -32601, "Method not found")
      end
    end

    private

    def initialize_result
      {
        "protocolVersion" => PROTOCOL_VERSION,
        "capabilities" => { "tools" => {} },
        "serverInfo" => { "name" => Agent::Discovery::SERVER_NAME, "version" => Agent::Discovery::SERVER_VERSION }
      }
    end

    def tools
      [
        {
          "name" => "search_products",
          "description" => "Search Afida's eco-packaging catalog by name, SKU, brand, or attributes.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "query" => { "type" => "string", "description" => "Search text, e.g. '12oz coffee cups'" },
              "category" => { "type" => "string", "description" => "Optional category slug" }
            },
            "required" => [ "query" ]
          }
        },
        {
          "name" => "get_product",
          "description" => "Fetch one catalog product by slug.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "slug" => { "type" => "string", "description" => "Product URL slug" }
            },
            "required" => [ "slug" ]
          }
        },
        {
          "name" => "list_categories",
          "description" => "List catalog categories and their children.",
          "inputSchema" => { "type" => "object", "properties" => {} }
        }
      ]
    end

    def call_tool(id, params)
      name = params["name"]
      arguments = params["arguments"] || {}
      payload = case name
      when "search_products"
        @catalog.products(query: arguments["query"], category: arguments["category"], per_page: 10)
      when "get_product"
        @catalog.product(arguments["slug"])
      when "list_categories"
        @catalog.categories
      else
        return rpc_result(id, { "content" => [ { "type" => "text", "text" => "Unknown tool: #{name}" } ], "isError" => true })
      end
      rpc_result(id, { "content" => [ { "type" => "text", "text" => JSON.generate(payload) } ] })
    rescue ActiveRecord::RecordNotFound
      rpc_result(id, { "content" => [ { "type" => "text", "text" => "Not found" } ], "isError" => true })
    end

    def rpc_result(id, result)
      { "jsonrpc" => "2.0", "id" => id, "result" => result }
    end

    def rpc_error(id, code, message)
      { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
    end

    def notification_ack
      :no_content
    end
  end
end
