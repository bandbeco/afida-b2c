---
type: Runbook
description: Why AI crawlers were blocked (Cloudflare's Block AI Bots setting, not the app), the API call that fixed it, and how to verify each User-Agent reaches the homepage.
status: active
timestamp: 2026-09-08
---

# AI Crawler Access

## The symptom

An agent-readiness audit on 2026-09-08 (Is Agentic score 71/100) reported ChatGPT-User, ClaudeBot and PerplexityBot as blocked, while GPTBot, Google-Extended and DeepSeekBot reached the homepage. `robots.txt` has explicit allow stanzas for ChatGPT-User, ClaudeBot, PerplexityBot, GPTBot and Google-Extended; DeepSeekBot is allowed only via `User-agent: *`. The site still published one policy and enforced another.

## Where the block lives

Not in this repository. A blocked request returns HTTP 403 with a 25-byte `text/plain` body (`Your request was blocked.`) and only Cloudflare headers (`server: cloudflare`, `cf-ray`, `expires: Thu, 01 Jan 1970`). A response that reached Rails carries `x-request-id`, `x-runtime` and `strict-transport-security`. The block is therefore decided at the Cloudflare edge, before the request reaches Kamal.

The app itself admits these User-Agents: `allow_browser versions: :modern` only rejects browsers it recognises with an old version, and `test/integration/ai_crawler_access_test.rb` pins that for each audited crawler. `AiCrawlers::REGISTRY` drives the `robots.txt` allow stanzas.

## The cause (confirmed 2026-09-08)

The zone's Bot Management setting `ai_bots_protection` was `block` (Security → Bots → "Block AI Bots"). Nothing else was involved: no legacy User-Agent rules, no IP access rules, Super Bot Fight Mode off, and none of the three custom WAF rules (internal API skip, Outrank webhook skip, signup challenge) match on User-Agent.

Cloudflare's own list of AI bots is what produced the split in the audit: ChatGPT-User, ClaudeBot and PerplexityBot are on it; a bare `GPTBot` token and Google-Extended are not.

## The fix

Set `ai_bots_protection` to `disabled`. Either flip "Block AI Bots" off in the dashboard, or with a zone-scoped API token holding "Bot Management: Edit" (the endpoint is PUT, not PATCH):

```
curl -X PUT -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  --data '{"ai_bots_protection":"disabled"}' \
  https://api.cloudflare.com/client/v4/zones/f5bf9fb80128e2cb3daf33ddc610244c/bot_management
```

Read the current state with a GET on the same URL. Propagation to the edge takes under a minute. Applied on 2026-09-08 with Laurent's approval; the token lives in the gitignored `mise.local.toml`, sourced from 1Password.

If a crawler is still blocked after this, check AI Crawl Control (per-crawler toggles) and any new WAF custom rule matching `http.user_agent` in the dashboard; those were clear at the time of writing.

Letting AI assistants read the catalogue is a business decision; `robots.txt` already said yes, so this brought the edge in line with the published policy.

## Verify

```
for ua in "ChatGPT-User" "ClaudeBot" "GPTBot" "PerplexityBot" "Google-Extended" \
  "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)"; do
  printf '%-70s ' "$ua"
  curl -s -o /dev/null -w "%{http_code}\n" -A "$ua" https://afida.com/
done
```

Every line must print `200`. A `403` with `server: cloudflare` and no `x-request-id` means the edge is still blocking.
