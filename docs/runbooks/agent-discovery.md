---
type: Runbook
description: Agent discovery surfaces on afida.com (well-known documents, catalog API, MCP, OAuth, DNS-AID) and the DNS records that must live at Cloudflare.
status: active
timestamp: 2026-09-08
---

# Agent discovery

Afida publishes machine-readable discovery so AI agents can find the catalog, MCP tools, and Stripe checkout without scraping HTML. The HTTP documents are served by Rails. DNS-AID records are not in the app; they have to be created on the Cloudflare zone with a token that can edit DNS.

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

`/.well-known/oauth-protected-resource` identifies the origin (`https://afida.com`) as `resource`. RFC 9728 requires that value to match the identifier used to fetch the origin-level well-known document; a path such as `/api/v1/acp` is treated as a mismatch. `/auth.md` is the WorkOS agentic-registration recipe (discover → register → authorize → exchange → revoke) and the `agent_auth` block on `/.well-known/oauth-authorization-server` uses `register_uri`, `identity_types_supported: ["anonymous"]`, and `anonymous.credential_types_supported`.

OAuth JWKS is an RSA key generated per process unless `AGENT_OAUTH_RSA_PEM` is set in the environment (a PKCS#1/PKCS#8 PEM). Set that in Kamal if agents will verify tokens across deploys.

## DNS-AID records

Publish these on `afida.com` (Cloudflare DNS). SVCB/HTTPS must be ServiceMode (priority > 0) with `alpn` and `port`. Do not publish `_a2a._agents`: Afida does not run an A2A agent. `_mcp._agents` is honest because `/mcp` exists.

```
_index._agents.afida.com.  3600  IN  HTTPS  1  afida.com.  alpn="h2,http/1.1" port=443
_mcp._agents.afida.com.    3600  IN  HTTPS  1  afida.com.  alpn="h2,http/1.1" port=443
_index._agents.afida.com.  3600  IN  TXT    "url=https://afida.com/.well-known/ai-catalog.json"
```

Published 2026-09-08 after adding **Zone.DNS Edit** to the zone token (zone id `f5bf9fb80128e2cb3daf33ddc610244c`). Re-apply with:

```
CLOUDFLARE_API_TOKEN=... bin/publish-dns-aid
```

Or POST each record:

```
curl -sS -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"HTTPS","name":"_index._agents","ttl":3600,"data":{"priority":1,"target":"afida.com","value":"alpn=\\"h2,http/1.1\\" port=443"}}' \
  https://api.cloudflare.com/client/v4/zones/f5bf9fb80128e2cb3daf33ddc610244c/dns_records
```

Verify over DNS-over-HTTPS (`Status` must be 0, not 3/NXDOMAIN):

```
curl -sS "https://cloudflare-dns.com/dns-query?name=_index._agents.afida.com&type=HTTPS" \
  -H "accept: application/dns-json"
curl -sS "https://cloudflare-dns.com/dns-query?name=_mcp._agents.afida.com&type=HTTPS" \
  -H "accept: application/dns-json"
```

DNSSEC is intentionally off. The HTTPS records already let agents find the catalog and MCP; signing the zone only makes validating resolvers set `AD=true`, and that needs a DS record at GoDaddy. A wrong DS SERVFAILs the whole domain. Leave Cloudflare DNSSEC disabled. The scanner will stay red on DNS-AID for `AD=false`.

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
