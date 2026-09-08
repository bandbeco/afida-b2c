---
type: Runbook
description: Agent discovery surfaces on afida.com (well-known documents, catalog API, MCP, OAuth, DNS-AID) and the DNS records that must live at Cloudflare.
status: active
timestamp: 2026-09-08
---

# Agent discovery

Afida publishes machine-readable discovery so AI agents can find the catalog, MCP tools, and Stripe checkout without scraping HTML. The HTTP documents are served by Rails. DNS-AID records are not in the app; they have to be created on the Cloudflare zone.

## HTTP surfaces

| Path | What it is |
| --- | --- |
| `/.well-known/api-catalog` | RFC 9727 linkset (`application/linkset+json`) |
| `/openapi.json` | OpenAPI 3.1 for the catalog and ACP checkout |
| `/.well-known/mcp/server-card.json` | MCP server card (also at `/.well-known/mcp.json`) |
| `/mcp` | Streamable HTTP MCP (`search_products`, `get_product`, `list_categories`) |
| `/api/v1/products` | Public JSON catalog |
| `/api/v1/categories` | Public JSON categories |
| `/.well-known/agent-skills/index.json` | Skills discovery index |
| `/.well-known/ai-catalog.json` | ARD capability manifest |
| `/auth.md` | How agents authenticate |
| `/.well-known/oauth-authorization-server` | RFC 8414 metadata |
| `/.well-known/oauth-protected-resource` | RFC 9728 metadata |
| `/oauth/register` | Dynamic client registration |
| `/oauth/token` | `client_credentials` |
| `/.well-known/acp.json` | Agentic Commerce Protocol discovery |
| `/api/v1/acp/checkout_sessions` | Creates a Stripe-hosted Checkout session |
| `/.well-known/ucp` | Universal Commerce Protocol profile |

The homepage `Link` header advertises `api-catalog`, `service-desc` (`/openapi.json`), `service-doc` (`/llms.txt`), and `describedby` (MCP card). `robots.txt` has an `Agentmap` line pointing at the ARD catalog.

Catalog GET endpoints and MCP tools are public: SKUs, prices, and pack sizes are the same data as the shop pages. Do not put them behind OAuth. Checkout still finishes on Stripe's hosted page (card). There is no x402 / crypto wallet.

OAuth JWKS is an RSA key generated per process unless `AGENT_OAUTH_RSA_PEM` is set in the environment (a PKCS#1/PKCS#8 PEM). Set that in Kamal if agents will verify tokens across deploys.

## DNS-AID records

Publish these on `afida.com` (Cloudflare DNS). SVCB/HTTPS must be ServiceMode (priority > 0) with `alpn` and `port`. Sign the zone with DNSSEC so validating resolvers accept the data.

```
_index._agents.afida.com.  3600  IN  HTTPS  1  afida.com.  alpn="h2,http/1.1" port=443
_mcp._agents.afida.com.    3600  IN  HTTPS  1  afida.com.  alpn="h2,http/1.1" port=443
_catalog._agents.afida.com. 3600 IN  TXT    "url=https://afida.com/.well-known/ai-catalog.json"
```

Apply with a zone-scoped token that can edit DNS (zone id `f5bf9fb80128e2cb3daf33ddc610244c`, same as [AI Crawler Access](/runbooks/ai-crawler-access.md)):

```
curl -sS -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"HTTPS","name":"_index._agents","priority":1,"data":{"target":"afida.com","priority":1,"value":"alpn=\\"h2,http/1.1\\" port=443"}}' \
  https://api.cloudflare.com/client/v4/zones/f5bf9fb80128e2cb3daf33ddc610244c/dns_records
```

Verify over DNS-over-HTTPS:

```
curl -sS "https://cloudflare-dns.com/dns-query?name=_index._agents.afida.com&type=HTTPS" \
  -H "accept: application/dns-json"
```

DNSSEC is a zone setting (DNS → Settings → DNSSEC). The scanner looks up `_index._agents` and `_a2a._agents` / `_mcp._agents` via DoH.

## Verify

```
curl -sS -D - -o /dev/null https://afida.com/ | grep -i ^link:
curl -sS https://afida.com/.well-known/api-catalog
curl -sS https://afida.com/.well-known/mcp/server-card.json
curl -sS -X POST https://isitagentready.com/api/scan \
  -H "Content-Type: application/json" \
  -d '{"url":"https://afida.com"}'
```

x402 will stay red: Afida does not take cryptocurrency. Do not publish a fake `payTo` wallet.
