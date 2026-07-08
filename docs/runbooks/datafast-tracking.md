---
type: Runbook
description: How Datafast analytics tracking is architected; the app owns the visitor id, gates server-side goals on pageview existence, and why.
status: active
timestamp: 2026-07-08
---

# Datafast Tracking Architecture

## Own the visitor id

The Datafast client script is supposed to set `cookies[:datafast_visitor_id]` but does not reliably do so. The app therefore mints the cookie itself (`ensure_datafast_visitor_id` before_action) and skips crawler endpoints (robots, sitemap, feed). The visitor id is persisted on `Order` so webhook-driven purchase goals never depend on a cookie being present at webhook time.

## Purchase goal routing

The script tag carries `data-disable-payments="true"`, so purchases ride the custom `purchase` goal fired server-side, not Datafast's automatic `payment` goal. If purchase counts look low, this chain is the place to look.

## The pageview gate

Datafast's client JS silently drops bots and JS-blocked clients, so Datafast has NO pageview for them; a server-side goal for such a visitor 404s with "no recorded pageviews". `DatafastService` therefore gates goal writes on `GET /visitors/:id` (404 means skip and log "[DataFast] skipped"; 200 means fire), cached 30 minutes, fail-open including on cache errors. Expect a residual gap between real orders and tracked `purchase` goals; that is bots and JS-blockers, not breakage.

## API key scopes

The website API key can READ fine (CLI `goals list` works) while goal-create WRITES 401 "Invalid API Key"; this happened in June 2026 (89 failed writes). Fix: regenerate the website API key in the Datafast dashboard (Website Settings, API), update `credentials.datafast.api_key`, redeploy. No code change.

## Local gotcha

A production-env `rails runner` hangs on `Rails.cache` access because Solid Cache points at the production DB. Test cache-touching paths on the server, not from a local production-env console.

## CLI

Read-only analytics pulls: `npx @datafast/cli analytics ...`, authenticated with the `df_` site key from credentials.
