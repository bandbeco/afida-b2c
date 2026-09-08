# frozen_string_literal: true

module Agent
  class Discovery
    SERVER_NAME = "Afida"
    SERVER_VERSION = "1.0.0"
    ACP_VERSION = "2025-09-29"
    UCP_VERSION = "2026-01-11"

    def initialize(base_url:)
      @base_url = base_url.to_s.delete_suffix("/")
    end

    def api_catalog
      {
        "linkset" => [
          {
            "anchor" => url("/api/v1/products"),
            "service-desc" => [
              { "href" => url("/openapi.json"), "type" => "application/vnd.oai.openapi+json" }
            ],
            "service-doc" => [
              { "href" => url("/llms.txt"), "type" => "text/plain" }
            ],
            "status" => [
              { "href" => url("/up") }
            ]
          },
          {
            "anchor" => url("/mcp"),
            "service-desc" => [
              { "href" => url("/.well-known/mcp/server-card.json"), "type" => "application/json" }
            ],
            "service-doc" => [
              { "href" => url("/llms.txt"), "type" => "text/plain" }
            ]
          }
        ]
      }
    end

    def mcp_server_card
      {
        "serverInfo" => {
          "name" => SERVER_NAME,
          "version" => SERVER_VERSION
        },
        "description" => "Search Afida's UK eco-packaging catalog, look up products, and list categories.",
        "url" => url("/mcp"),
        "transport" => { "type" => "streamable-http" },
        "capabilities" => { "tools" => true, "resources" => false, "prompts" => false }
      }
    end

    def agent_skills_index
      {
        "$schema" => "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
        "skills" => Agent::Skills.all.map { |skill|
          {
            "name" => skill.name,
            "type" => "skill-md",
            "description" => skill.description,
            "url" => url("/.well-known/agent-skills/#{skill.name}/SKILL.md"),
            "digest" => skill.digest
          }
        }
      }
    end

    def ard
      host = URI.parse(@base_url).host
      {
        "specVersion" => "1.0",
        "host" => {
          "displayName" => "Afida",
          "identifier" => "did:web:#{host}"
        },
        "entries" => [
          {
            "identifier" => "urn:air:#{host}:server:mcp",
            "displayName" => "Afida catalog MCP server",
            "type" => "application/mcp-server-card+json",
            "url" => url("/.well-known/mcp/server-card.json"),
            "representativeQueries" => [
              "search Afida for compostable coffee cups",
              "what pizza boxes does Afida sell",
              "find wooden cutlery in the Afida catalog"
            ]
          },
          {
            "identifier" => "urn:air:#{host}:api:catalog",
            "displayName" => "Afida product catalog API",
            "type" => "application/vnd.oai.openapi+json",
            "url" => url("/openapi.json"),
            "representativeQueries" => [
              "list Afida products as JSON",
              "OpenAPI spec for the Afida shop",
              "look up a product by SKU on Afida"
            ]
          },
          {
            "identifier" => "urn:air:#{host}:skills:index",
            "displayName" => "Afida agent skills",
            "type" => "application/json",
            "url" => url("/.well-known/agent-skills/index.json"),
            "representativeQueries" => [
              "how should an agent shop at Afida",
              "request free packaging samples from Afida",
              "order branded coffee cups from Afida"
            ]
          }
        ]
      }
    end

    def oauth_authorization_server
      {
        "issuer" => @base_url,
        "authorization_endpoint" => url("/oauth/authorize"),
        "token_endpoint" => url("/oauth/token"),
        "jwks_uri" => url("/oauth/jwks"),
        "registration_endpoint" => url("/oauth/register"),
        "grant_types_supported" => [ "client_credentials" ],
        "response_types_supported" => [ "token" ],
        "token_endpoint_auth_methods_supported" => [ "client_secret_post" ],
        "scopes_supported" => [ "checkout.write" ],
        "agent_auth" => {
          "skill" => url("/auth.md"),
          "register_uri" => url("/oauth/register"),
          "identity_types_supported" => [ "anonymous" ],
          "anonymous" => {
            "credential_types_supported" => [ "client_secret" ],
            "claim_uri" => url("/oauth/register")
          }
        }
      }
    end

    def oauth_protected_resource
      {
        "resource" => url("/api/v1/acp"),
        "authorization_servers" => [ @base_url ],
        "scopes_supported" => [ "checkout.write" ],
        "bearer_methods_supported" => [ "header" ]
      }
    end

    def ucp
      {
        "protocol_version" => UCP_VERSION,
        "ucp" => {
          "version" => UCP_VERSION,
          "services" => {
            "dev.ucp.shopping.catalog" => {
              "version" => "2026-01-11",
              "spec" => "https://ucp.dev/specification/overview/"
            }
          },
          "capabilities" => [ "dev.ucp.shopping.catalog" ],
          "payment_handlers" => {
            "com.stripe" => {
              "version" => "2025-09-29",
              "spec" => "https://docs.stripe.com/payments/checkout"
            }
          }
        },
        "services" => [ "catalog", "checkout" ],
        "capabilities" => [ "catalog.search", "catalog.lookup", "checkout.redirect" ],
        "endpoints" => {
          "catalog" => url("/api/v1/products"),
          "checkout" => url("/api/v1/acp/checkout_sessions"),
          "openapi" => url("/openapi.json")
        }
      }
    end

    def acp
      {
        "protocol" => {
          "name" => "acp",
          "version" => ACP_VERSION,
          "supported_versions" => [ ACP_VERSION ]
        },
        "api_base_url" => url("/api/v1/acp"),
        "transports" => [ "rest" ],
        "capabilities" => {
          "services" => [ "checkout" ]
        }
      }
    end

    def auth_md
      <<~MARKDOWN
        # auth.md

        Afida is a UK eco-packaging shop. The product catalog is public. Prices, SKUs, and pack sizes are not confidential.

        ## Public catalog (no authentication)

        Do not send tokens. These endpoints return 200 without `Authorization`:

        - REST: `#{url("/api/v1/products")}` and `#{url("/api/v1/categories")}`
        - OpenAPI: `#{url("/openapi.json")}`
        - MCP (Streamable HTTP): `#{url("/mcp")}`
        - Overview: `#{url("/llms.txt")}`

        ## Optional agent credentials

        Dynamic client registration at `#{url("/oauth/register")}` issues `client_id` and `client_secret`.
        Exchange them at `#{url("/oauth/token")}` with `grant_type=client_credentials`.
        A bearer token is not required for the catalog, MCP, or checkout.

        ## Human accounts

        Customers create a session cookie account at `#{url("/signup")}` and sign in at `#{url("/signin")}`.
        That flow is for browsers, not agents.

        ## Payments

        Checkout is Stripe (card). An agent can create a hosted Checkout session at
        `#{url("/api/v1/acp/checkout_sessions")}`; the buyer completes payment on Stripe.
        Afida does not accept cryptocurrency or x402 settlement.
      MARKDOWN
    end

    def url(path)
      "#{@base_url}#{path}"
    end
  end
end
