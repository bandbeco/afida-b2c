# Afida Foundation — a lean, brandable, region-configurable commerce app

**Date:** 2026-06-19
**Status:** Design (approved in brainstorm, pending spec review)
**Origin:** Tariq asked whether we could "copy the same site to another domain, different name and colours, like for like" for a friend in Romania, suggesting "a quick £3k." A literal like-for-like copy is the wrong shape: it would saddle the friend with Afida-specific catalogue data, UK-only delivery/VAT/holiday logic, and live integrations wired to Afida's own accounts. This design replaces the clone idea with a one-time refactor of the Afida codebase into a reusable foundation, of which Afida is the first configured instance and the friend's store is the second.

## 1. Goal & scope

### Goal

Refactor the live Afida Rails 8 application **in place** into a lean, brandable, region-configurable foundation, so that standing up a new store **in the same niche** (foodservice packaging) is a matter of **configuration and data entry, not code editing**. Afida becomes "configured instance #1" of its own code; Tariq's friend's Romanian store becomes a second deploy configured from the same codebase.

This is the "Option B — lean reusable foundation" path chosen in the brainstorm: the friend funds a foundation that makes a second buyer cheap, without gold-plating ahead of demand. It deliberately keeps the option open to evolve toward a multi-tenant SaaS (Option C) later by cutting clean seams, but builds none of that now.

### In scope

Four configuration seams layered onto the existing app:

1. **Brand layer** — name, logo, colours, contact details, social links, legal entity, brand-specific copy.
2. **Locale layer** — currency, VAT rules, the delivery-promise engine, date/number formatting, and full Romanian i18n of all customer-facing copy.
3. **Integration layer** — Stripe, Datafast, Telegram, BetterStack, Klaviyo, Outrank become credential-driven, with safe no-op defaults when keys are absent.
4. **Catalogue & content** — the friend's own products, pricing, suppliers, and blog, entered through the existing admin (data, not code).

### Out of scope (YAGNI)

- Multi-tenancy (a single app serving multiple stores from one process).
- Self-serve onboarding, subscription billing, a theme/UI builder.
- Any niche other than foodservice packaging.
- Full SaaS productisation (Option C).

These are explicitly deferred. The design cuts clean seams so they remain *possible*, but builds nothing speculative toward them.

### Key decisions made in the brainstorm

- **Refactor in place, do not clone.** A clone produces two diverging codebases and recreates the per-customer manual-fork trap the foundation is meant to escape. One source of truth is the whole point. (Decision: Option 1 over Option 2.)
- **The friend's store is a separate deploy**, not a tenant inside Afida. Same code, different config + data + deploy target — exactly as Afida is deployed today.
- **Same niche** means the packaging domain (catalogue schema, branded-product configurator, product logic) carries over as a reusable asset; it is not stripped.
- **Full Romanian i18n** is in scope (an English-only Romanian store would convert poorly), but is fenced as its own workstream.
- **Integrations are credential-driven with no-op defaults** — absent keys disable an integration cleanly, never error, never fall back to Afida's accounts.

## 2. Architecture — the deploy substrate + four config seams

A new store touches only configuration and data, never application code — but "configuration" has two layers. Beneath the four customer-facing seams sits a **deploy substrate** that decides *which instance a running process is*: which config it loads, which secrets it holds, which database it talks to, and which domain it serves. The substrate is specified first because every seam depends on it, and because it is the layer that makes "zero Afida values reachable" (DoD #3) actually true.

### 2.0 Deploy substrate (per-instance identity & isolation)

**What it does:** gives each deploy its own identity and complete isolation from every other deploy. This is the answer to "how does the friend's store know it is the friend's store, and how do we guarantee it can never reach Afida's data, secrets, or accounts."

**Config selection.** Each deploy is pinned to an instance via a single environment variable (e.g. `APP_INSTANCE=afida` / `APP_INSTANCE=<friend>`), injected by Kamal. All non-secret per-instance config (brand, locale, site identity) lives in a committed, instance-keyed file (e.g. `config/instances/<instance>.yml`) selected by that variable. Committing these is correct: they contain no secrets, and keeping them in one repo is what preserves the single-source-of-truth the in-place refactor is built on.

**Secrets & master key.** The codebase today reads integrations, asset host, and mailer host from a **single shared `credentials.yml.enc` gated by one `RAILS_MASTER_KEY`** (see `config/environments/production.rb`, `config/initializers/stripe.rb`, `app/services/*`). Secrets therefore cannot move into a committed instance file. The friend's deploy gets its **own encrypted credentials** (`config/credentials/<instance>.yml.enc` + its own `<INSTANCE>_RAILS_MASTER_KEY`) — or, equivalently, env-injected secrets via Kamal — so no Afida secret is decryptable from his deploy. The brand seam's "domain/canonical/asset host" values move from credentials into the non-secret instance file; only true secrets (API keys, webhook secrets) stay in encrypted credentials.

**Kamal destination.** `config/deploy.yml` today is single-destination, single-server (hardcoded `service: afida-b2c`, `image: bandbeco/afida-b2c`, one `servers.web` IP, `proxy.hosts: [afida.com, www.afida.com]`, `APP_HOST`, BetterStack tokens). The second store is provisioned as a **Kamal destination** (`config/deploy.<instance>.yml`, deployed with `-d <instance>`) carrying its own service name, image namespace, server/host, proxy hosts, `APP_INSTANCE`, and master-key secret. Deploy config is files-in-repo, so this is real work, not free; it is explicitly part of standing up a store (sequencing step 0).

**Database topology.** Each deploy gets its **own Postgres database(s)** (`<instance>_production` + `_cache`/`_queue`/`_cable`), provisioned on its own host/accessory. No shared database — sharing would put Afida's catalogue, orders, and customer PII one query away from the friend's app and would make DoD #3 false. Database name/host is derived from the instance.

**Depends on:** nothing (it is the foundation the seams sit on).

**Done when:** setting `APP_INSTANCE=<x>` boots a process that loads only instance `<x>`'s config, can decrypt only `<x>`'s credentials, connects only to `<x>`'s database, and serves only `<x>`'s domain; Afida continues to run with `APP_INSTANCE=afida` and today's values.

### 2.1 Brand layer (incl. site identity)

**What it does:** provides a single source of truth for all brand-specific presentation values **and site identity** (the domain-level facts that make a second store crawlable under its own domain without leaking Afida URLs).

**Interface:** the non-secret instance file (§2.0) read into a `Brand` accessor, plus CSS custom properties for colour and logo. All views, mailers, and stylesheets consume brand values through a helper rather than hardcoding them.

**Scope of extraction:**
- *Presentation:* the current codebase has ~1,766 hardcoded "afida" references across 40+ files (views, mailers, stylesheets, a JS controller, the Telegram job, the price-list controller). These are relocated into the instance config and read back through the helper / CSS variables.
- *Site identity:* the hardcoded canonical-host 301 in `config/routes.rb` (`constraints(host: "www.afida.com")`), the `data-domain="afida.com"` and `staging.afida.com` check in the application layout, `APP_HOST` / `asset_host` / canonical-URL generation, the committed root-level `*-sitemap.xml` files plus `SitemapGeneratorService` and `robots_controller`. These become instance-derived so a second domain produces its own canonical URLs, sitemaps, and robots output, and emits its own analytics domain — never Afida's. (For an SEO-driven business this is load-bearing, not polish.)

**Depends on:** the deploy substrate (§2.0).

**Done when:** characterisation tests are green — Afida's rendered DOM, visual output, canonical URLs, sitemap/robots output, and computed values are unchanged from the pre-refactor app, with all brand/identity values now sourced from the instance config.

### 2.2 Locale layer

**What it does:** externalises everything region-specific so the same code serves a UK store (Afida) and a Romanian store.

This seam splits into two distinct kinds of work:

**2.2a Locale rules (config):**
- Currency (GBP for Afida, RON/EUR for the friend) and money formatting.
- VAT rate(s) and how VAT is applied. (Flag: Romanian VAT may exceed a single-rate swap — multiple rates, and possible reverse-charge / EU B2B / OSS handling. The seam externalises rate(s) and application logic; the precise RO semantics are to be confirmed during planning, not assumed equal to UK VAT.)
- The delivery-promise engine — currently hardwired UK logic (next-working-day, 2pm cutoff, UK bank holidays via the `BankHoliday` model / `DeliveryEstimate`). The promise rules, cutoff, working-week, and holiday source become configuration. (Note: the delivery promise is the source of truth consumed by product-page JS, order confirmation, and Google Customer Reviews — all derivations must continue to read from the same place.)
- Date and number formatting.

**2.2b Locale strings (i18n):**
- Extract all customer-facing copy into Rails locale files via `t()`. The oracle for "`en.yml` reproduces today's copy" is a **snapshot of rendered pages captured before extraction**, asserted to match after extraction — not a manual eyeball of inline ERB.
- Generate `ro.yml` (machine translation as a first pass, then native-speaker review).
- This is the single largest line item in the project and is fenced as its own workstream so it cannot smear across the other seams.

**Depends on:** the brand layer (for any brand name embedded in copy) and the deploy substrate.

**Done when:** Afida runs unchanged on UK locale config + `en`; a Romanian deploy renders in `ro` with RON pricing, Romanian VAT, and a region-appropriate delivery promise; no customer-facing view emits a missing-translation key.

### 2.3 Integration layer

**What it does:** ensures every third-party integration is per-instance and that a deploy never touches another deploy's accounts.

**Interface:** each of Stripe, Datafast, Telegram, BetterStack, Klaviyo, and Outrank reads its credentials from per-instance configuration. When an integration's credentials are absent, it **cleanly no-ops** — no error, no fallback to Afida's accounts.

**Depends on:** nothing.

**Done when:** Afida, with its keys present, behaves exactly as today; a keyless instance boots and functions with all integrations silently disabled.

### 2.4 Catalogue & content

**What it does:** holds the store's own products, pricing, suppliers, and blog content.

**Interface:** the existing admin, plus a bulk-import path (CSV/seed) for products, suppliers, and pricing so the friend isn't hand-keying a catalogue. Because he is in the same niche, the catalogue schema and branded-product configurator carry over unchanged.

**Clean-slate data.** A fresh deploy must start with **no Afida data**. `db/seeds.rb` and any fixtures/demo content are reviewed so that seeding a new instance creates only structural/reference rows, never Afida's catalogue, blog, orders, or PII. The friend's database is provisioned empty (§2.0) and populated only via his admin/import. This is what makes DoD #3 ("zero Afida values reachable") true at the data layer as well as the config layer.

**Depends on:** the deploy substrate (his DB), and brand + locale being in place (so the store renders correctly as content is added).

**Done when:** the friend's catalogue and content exist in his deploy, rendered under his brand and locale, and a fresh instance contains no Afida-originated rows.

### 2.5 Runtime data flow (per request)

1. Request arrives at a given deploy, which boots with `APP_INSTANCE=<x>` (§2.0).
2. Instance config (brand + site identity + locale) is resolved once from `config/instances/<x>.yml`; secrets from `<x>`'s encrypted credentials; the connection points at `<x>`'s database.
3. Views and mailers read brand values via the brand helper, copy via `t()`, and money/dates via locale formatters; canonical URLs / sitemaps / robots / analytics domain derive from `<x>`'s site identity.
4. Integrations act only if their credentials are present for that deploy.
5. No Afida config, secret, database row, or domain value is reachable from a non-Afida deploy.

## 3. Sequencing

The seams ship in an order that keeps Afida verifiably intact at every step and brings the friend's store together late, on a stable base. Steps 1–3 are pure behaviour-preserving refactors of the live app, shippable to Afida immediately (paying down existing debt). Step 0 is a prerequisite enabler; steps 4–6 are friend-specific.

0. **Deploy substrate** — introduce `APP_INSTANCE` selection, the instance-config file, the per-instance credentials/master-key model, the Kamal-destination pattern, and DB-per-instance. Afida runs as `APP_INSTANCE=afida` on today's values. This unblocks every later step that reads instance config.
1. **Brand layer (incl. site identity)** — lowest risk, highest sprawl. Extract hardcoded refs + site-identity (canonical host, sitemaps, robots, analytics domain) into the instance config + `Brand` accessor + CSS custom properties. Afida config = current values; characterisation tests green (rendered output and computed values unchanged).
2. **Integration layer** — make all six credential-driven with no-op defaults. Afida keeps its keys; nothing changes for the live shop.
3. **Locale rules** — currency, VAT, delivery-promise engine, bank-holiday source, formatting become config. Afida config = UK values; behaviour unchanged.
4. **Locale strings (i18n)** — extract customer-facing copy to `en.yml` (snapshot-verified), then generate and review `ro.yml`. Isolated workstream.
5. **Clean-slate data review** — ensure `db/seeds.rb`/fixtures carry no Afida data into a fresh instance; provide the catalogue bulk-import path.
6. **Stand up the friend's store** — second Kamal destination from the same code: his instance config, `ro` locale, his own credentials (Stripe/email/webhooks), his database, his catalogue.

## 4. Testing strategy

Per the project's always-TDD rule for application code:

- **Deploy substrate:** test that `APP_INSTANCE=afida` resolves Afida's config/credentials/DB and today's behaviour, and that a different `APP_INSTANCE` resolves only that instance's config, cannot decrypt Afida's credentials, and points at a different database.
- **Brand & locale-rules seams:** characterisation tests first. Capture Afida's current rendered output and computed values (delivery dates, VAT, prices, canonical URLs, sitemap/robots output), then refactor until green. Because Afida's config equals today's hardcoded values, "behaviour unchanged" is the pass condition.
- **Integration seam:** test both states explicitly — keys present (behaves as today) and keys absent (no-ops cleanly, no error, no Afida fallback). The keyless case is the guardrail that protects the friend's store.
- **i18n seam:** assert no customer-facing view emits a missing-translation key, and that the pre-extraction rendered-page snapshot still matches for `en`. Translation *quality* is human-reviewed by a native speaker, not unit-tested.
- **Friend's store:** a smoke pass on a real deploy — boots, renders in Romanian, a test order completes through *his* Stripe in RON via *his* webhook endpoint, no Afida rows are present, and integrations he has not configured stay silent.

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Breaking the live shop during in-place refactor | Every seam is a behaviour-preserving refactor, characterisation-tested, shipped incrementally; Afida config reproduces current values exactly. |
| Integration leak (Afida's accounts firing on the friend's store) | The keyless no-op test is the guardrail; absent credentials disable an integration, never fall back. |
| i18n scope creep | Fenced as its own workstream with its own definition of done; not allowed to bleed into the other three seams. |
| Over-building toward SaaS | Multi-tenancy, billing, and onboarding are explicitly out of scope; we cut seams, not platform. |
| Two diverging codebases | Avoided by design: refactor in place, one source of truth; the friend's store is a configured deploy, not a clone. |
| Shared `credentials.yml.enc` / single master key | Each deploy gets its own encrypted credentials + master key (or env-injected secrets); no Afida secret is decryptable from another deploy (§2.0). |
| Shared database | DB-per-deploy is mandated (§2.0); no shared Postgres, so Afida's catalogue/orders/PII are unreachable from the friend's app. |
| Stripe (and Outrank) webhook routing per deploy | Each deploy registers its own Stripe webhook endpoint + its own `webhook_secret` in its own credentials; the friend's-store smoke test exercises a real order through *his* endpoint. |
| Leaking Afida analytics/identity | Datafast `data-domain`, GA4, GCR merchant id, BetterStack ingest token, canonical host, and sitemaps all derive from instance config (§2.0/2.1); a non-Afida deploy emits only its own. |

## 6. Definition of done

1. Afida runs unchanged on the refactored code (as `APP_INSTANCE=afida`), full test suite green.
2. A keyless instance boots with all integrations silently disabled.
3. The friend's store is live on its own Kamal destination — Romanian UI, RON pricing, his own credentials (Stripe/email/webhooks), his own database and catalogue — with zero Afida config, secrets, database rows, or domain values reachable from it.

## 7. Commercial framing (context, not build scope)

The reply to Tariq reframes the ask: a like-for-like copy would hurt his friend (Afida-specific data, UK-only logic, shared integrations) and £3k undersells the real work. The better offer is a proper reusable foundation the friend runs as his own Romanian brand, with the same foundation available to future buyers. The friend is paying customer #1 and a demand-validation signal; only if several paying installs materialise does evolving toward a multi-tenant SaaS (Option C) become justified.
