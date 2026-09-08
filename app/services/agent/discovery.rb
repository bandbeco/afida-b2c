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
        "resource" => @base_url,
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

        You are an agent. This service supports **agentic registration**: discover → register → authorize → exchange for an access token → call the API → handle revocation. Follow the steps in order.

        Afida is a UK eco-packaging shop. The product catalog is public. Prices, SKUs, and pack sizes are not confidential.

        ## Step 1 — Discover

        Fetch `#{url("/.well-known/oauth-protected-resource")}` (RFC 9728) and `#{url("/.well-known/oauth-authorization-server")}` (RFC 8414). The `agent_auth` block carries this skill (`skill`), the registration endpoint (`register_uri`), and `identity_types_supported` (`anonymous`).

        These endpoints return 200 without `Authorization`:

        - REST: `#{url("/api/v1/products")}` and `#{url("/api/v1/categories")}`
        - OpenAPI: `#{url("/openapi.json")}`
        - MCP (Streamable HTTP): `#{url("/mcp")}`
        - Overview: `#{url("/llms.txt")}`

        ## Step 2 — Register

        Dynamic Client Registration (RFC 7591): POST client metadata to `register_uri` (`#{url("/oauth/register")}`).

        ```http
        POST /oauth/register
        Content-Type: application/json

        { "client_name": "your-agent" }
        ```

        The response is `client_id` and `client_secret`. Identity type is anonymous; credential type is `client_secret`. Claim and manage credentials at the same `claim_uri`.

        ## Step 3 — Authorize

        Afida issues agent tokens with `grant_type=client_credentials`. There is no interactive authorization-code redirect for agents. Humans sign in at `#{url("/signin")}` and create a session cookie account at `#{url("/signup")}`.

        ## Step 4 — Exchange

        POST to the `token_endpoint` (`#{url("/oauth/token")}`):

        ```http
        POST /oauth/token
        Content-Type: application/x-www-form-urlencoded

        grant_type=client_credentials&client_id=...&client_secret=...
        ```

        The response is a Bearer access token that expires in 3600 seconds.

        ## Step 5 — Use the access token

        Send `Authorization: Bearer <token>` if you hold one. A bearer token is not required for the catalog, MCP, or checkout.

        Checkout is Stripe (card). An agent can create a hosted Checkout session at `#{url("/api/v1/acp/checkout_sessions")}`; the buyer completes payment on Stripe. Afida does not accept cryptocurrency or x402 settlement.

        ## Revocation

        Tokens are short-lived JWTs. Discard `client_secret` and the access token when finished. There is no persistent token store; tokens expire in 3600 seconds.
      MARKDOWN
    end

    def url(path)
      "#{@base_url}#{path}"
    end
  end
end
