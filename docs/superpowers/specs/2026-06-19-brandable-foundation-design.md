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

## 2. Architecture — the four config seams

Each seam has one clear purpose, a well-defined interface, and can be understood and tested independently. A new store touches only configuration and data, never application code.

### 2.1 Brand layer

**What it does:** provides a single source of truth for all brand-specific presentation values.

**Interface:** a `config/brand.yml` file (per deploy) read into a `Brand` accessor, plus CSS custom properties for colour and logo. All views, mailers, and stylesheets consume brand values through a helper rather than hardcoding them.

**Scope of extraction:** the current codebase has ~1,766 hardcoded "afida" references across 40+ files (views, mailers, stylesheets, a JS controller, the Telegram job, the price-list controller). These are relocated into the brand config and read back through the helper / CSS variables.

**Depends on:** nothing.

**Done when:** Afida, with `brand.yml` populated from today's hardcoded values, renders byte-identical to the pre-refactor app.

### 2.2 Locale layer

**What it does:** externalises everything region-specific so the same code serves a UK store (Afida) and a Romanian store.

This seam splits into two distinct kinds of work:

**2.2a Locale rules (config):**
- Currency (GBP for Afida, RON/EUR for the friend) and money formatting.
- VAT rate(s) and how VAT is applied.
- The delivery-promise engine — currently hardwired UK logic (next-working-day, 2pm cutoff, UK bank holidays via the `BankHoliday` model / `DeliveryEstimate`). The promise rules, cutoff, working-week, and holiday source become configuration. (Note: the delivery promise is the source of truth consumed by product-page JS, order confirmation, and Google Customer Reviews — all derivations must continue to read from the same place.)
- Date and number formatting.

**2.2b Locale strings (i18n):**
- Extract all customer-facing copy into Rails locale files via `t()` (`en.yml` reproduces today's copy exactly).
- Generate `ro.yml` (machine translation as a first pass, then native-speaker review).
- This is the single largest line item in the project and is fenced as its own workstream so it cannot smear across the other seams.

**Depends on:** the brand layer (for any brand name embedded in copy).

**Done when:** Afida runs unchanged on UK locale config + `en`; a Romanian deploy renders in `ro` with RON pricing, Romanian VAT, and a region-appropriate delivery promise; no customer-facing view emits a missing-translation key.

### 2.3 Integration layer

**What it does:** ensures every third-party integration is per-instance and that a deploy never touches another deploy's accounts.

**Interface:** each of Stripe, Datafast, Telegram, BetterStack, Klaviyo, and Outrank reads its credentials from per-instance configuration. When an integration's credentials are absent, it **cleanly no-ops** — no error, no fallback to Afida's accounts.

**Depends on:** nothing.

**Done when:** Afida, with its keys present, behaves exactly as today; a keyless instance boots and functions with all integrations silently disabled.

### 2.4 Catalogue & content

**What it does:** holds the store's own products, pricing, suppliers, and blog content.

**Interface:** the existing admin. This is **data entry, not code.** Because the friend is in the same niche, the catalogue schema and branded-product configurator carry over unchanged; he supplies his own products, pricing, and suppliers, and his own blog/SEO content.

**Depends on:** brand and locale being in place first (so the store renders correctly as content is added).

**Done when:** the friend's catalogue and content exist in his deploy, rendered under his brand and locale.

### 2.5 Runtime data flow (per request)

1. Request arrives at a given deploy.
2. Instance config (brand + locale) is resolved once.
3. Views and mailers read brand values via the brand helper, copy via `t()`, and money/dates via locale formatters.
4. Integrations act only if their credentials are present for that deploy.
5. No Afida-specific value is reachable from a non-Afida deploy.

## 3. Sequencing

The seams ship in an order that keeps Afida verifiably intact at every step and brings the friend's store together late, on a stable base. The first three steps are pure behaviour-preserving refactors of the live app and are shippable to Afida immediately (paying down existing debt); only steps 4–5 are friend-specific.

1. **Brand layer** — lowest risk, highest sprawl, unblocks everything visual. Extract hardcoded refs into `brand.yml` + `Brand` accessor + CSS custom properties. Afida config = current values; diff renders byte-identical.
2. **Integration layer** — make all six credential-driven with no-op defaults. Afida keeps its keys; nothing changes for the live shop.
3. **Locale rules** — currency, VAT, delivery-promise engine, bank-holiday source, formatting become config. Afida config = UK values; behaviour unchanged.
4. **Locale strings (i18n)** — extract customer-facing copy to `en.yml`, then generate and review `ro.yml`. Isolated workstream.
5. **Stand up the friend's store** — second deploy from the same code: his `brand.yml`, `ro` locale, his Stripe/email keys, his catalogue via admin.

## 4. Testing strategy

Per the project's always-TDD rule for application code:

- **Brand & locale-rules seams:** characterisation tests first. Capture Afida's current rendered output and computed values (delivery dates, VAT, prices), then refactor until green. Because Afida's config equals today's hardcoded values, "behaviour unchanged" is the pass condition.
- **Integration seam:** test both states explicitly — keys present (behaves as today) and keys absent (no-ops cleanly, no error, no Afida fallback). The keyless case is the guardrail that protects the friend's store.
- **i18n seam:** assert no customer-facing view emits a missing-translation key, and that `en.yml` reproduces today's copy. Translation *quality* is human-reviewed by a native speaker, not unit-tested.
- **Friend's store:** a smoke pass on a real deploy — boots, renders in Romanian, a test order completes through *his* Stripe in RON, and integrations he has not configured stay silent.

## 5. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Breaking the live shop during in-place refactor | Every seam is a behaviour-preserving refactor, characterisation-tested, shipped incrementally; Afida config reproduces current values exactly. |
| Integration leak (Afida's accounts firing on the friend's store) | The keyless no-op test is the guardrail; absent credentials disable an integration, never fall back. |
| i18n scope creep | Fenced as its own workstream with its own definition of done; not allowed to bleed into the other three seams. |
| Over-building toward SaaS | Multi-tenancy, billing, and onboarding are explicitly out of scope; we cut seams, not platform. |
| Two diverging codebases | Avoided by design: refactor in place, one source of truth; the friend's store is a configured deploy, not a clone. |

## 6. Definition of done

1. Afida runs unchanged on the refactored code, full test suite green.
2. A keyless instance boots with all integrations silently disabled.
3. The friend's store is live on its own deploy — Romanian UI, RON pricing, his Stripe, his catalogue — with zero Afida values reachable from it.

## 7. Commercial framing (context, not build scope)

The reply to Tariq reframes the ask: a like-for-like copy would hurt his friend (Afida-specific data, UK-only logic, shared integrations) and £3k undersells the real work. The better offer is a proper reusable foundation the friend runs as his own Romanian brand, with the same foundation available to future buyers. The friend is paying customer #1 and a demand-validation signal; only if several paying installs materialise does evolving toward a multi-tenant SaaS (Option C) become justified.
