# Update Log

## 2026-08-18

* **Creation**: [SEO Measurement Checkpoint 2026-08-18](/seo/seo-audit-2026-08-18.md). The ~Aug-16 28-day GSC pull the July audit committed to, read directly from the GSC UI. Verdicts: W1 category retitles produced no click effect (27 to 15 clicks, position is the constraint); napkins-restaurants content ranks page-1 across its family but is clickless (AI-shaped queries), so replication is on hold; the July blog refresh scored one clear win (pizza post 3 to 10 clicks at flat position) and three neutrals; June rename equity is fully consolidated but at a lower level (new ice-cream-cups 4 clicks / pos 14.6 vs old 12 / 9.8); B1 gate failed a second time so guide batch 2 stays paused; quick_add indexing decaying on schedule (876, target ~755). Also corrects the record: Roadmap Tasks 11 (/vegware consolidation) and 18 (merchant-feed taxonomy) never shipped and are now the top next plays. Backlog re-prioritised, SEO index updated. Note: the doc's §4 is now the bundle's first written record of the 2026-07-21 blog refresh.

## 2026-08-17

* **Creation**: [Hormozi Trilogy Implementation Plan](/plans/2026-08-17-hormozi-trilogy-implementation.md). Consolidates the three August 2026 Hormozi proposals' interlocking build orders into one four-phase checklist (now / next / then / gated) with per-item ownership (dev retainer vs Afida leadership), the deliberately-unplanned items, and the shared monthly scoreboard. Records groundwork already done: reorder-schedule expiry dead-end fix (master `1d8c0d58`) and the zombie schedule repair. Plans index updated.

## 2026-08-09

* **Creation**: [Leads Proposal (August 2026)](/proposals/leads-2026-08.md). Completes the Hormozi trilogy, applying *$100M Leads* (2023) to the layer before the offer: how strangers find out it exists. Diagnosis: Afida works a fraction of one of the book's four advertising channels (content), while warm outreach, cold outreach and all four lead getters sit at zero, and those are the free ones. Six plays, led by warm outreach over the trade book and lapsed buyers, a two-sided product-denominated referral ask at purchase, and an outreach last mile for the lead monitor (new-opening kit as the cold offer); sample request adopted as the engaged-lead unit; paid ads stay gated on repeat purchase per the book's own LTGP:CAC rule. Proposals index updated.
* **Creation**: [Grand Slam Offer Proposal (August 2026)](/proposals/grand-slam-offer-2026-08.md). Companion to the money-model proposal, applying Hormozi's *$100M Offers* (2021) to the front end. Diagnosis: Afida sells commodities presented as commodities while every differentiating asset (next-working-day 2pm-cutoff delivery, free samples, compatible-lids data, branded configurator) already exists but is not composed into an offer. Six plays, led by a Grand Slam Offer for new food-business openings (the lead monitor's starving crowd), value-equation denominator copy (speed and effort), and named guarantees. The money-model doc gained a companion cross-link.
* **Creation**: [Money Model Proposal (August 2026)](/proposals/money-model-2026-08.md). Applies Hormozi's *$100M Money Models* offer-sequence framework to afida.com. Diagnosis from production data (120 paid orders / £96 AOV over 180 days; 86 of 99 customers bought exactly once; 1 active reorder schedule): the attraction layer works but the model ends at the first purchase. Six plays prioritised, led by continuity bonuses on the existing reorder-schedule machinery, free-framed reframes of the welcome offer and quantity tiers, and a sample-to-prescription funnel tied to the lead monitor.

## 2026-07-31

* **Update**: [Timesheet July 2026](/reports/timesheet-2026-07.md) extended through 29 Jul, picking up the on-site checkout build (28 Jul session plus the 29 Jul hardening commit): 20.00 h development (19 sessions over 14 active days). Owner then waived all non-code lines, so July bills development only: 20.0 h at £50/h, invoiced as AFIDA-2026-07.

## 2026-07-29

* **Update**: [Developer Guide](/developer_guide.md) checkout section: the mode decision is now `OnsiteCheckout.enabled?(session)`, adding a session-sticky production preview (`?onsite_checkout=1` on any URL, `=0` to clear) alongside the global `ONSITE_CHECKOUT` env flag (`onsite-checkout` branch, PR #271).

## 2026-07-28

* **Creation**: [Timesheet July 2026](/reports/timesheet-2026-07.md). Measured-elapsed hours for July: 18.25 h development (18 git sessions over 13 active days, including the unmerged `lead-monitor` branch) plus 4.5 h estimated analytics/SEO/platform work; 22.75 h total at £50/h.
* **Update**: [On-Site Checkout Plan](/superpowers/plans/2026-07-28-onsite-checkout.md) and the [Developer Guide](/developer_guide.md) gained OKF frontmatter (code-review follow-up on the `onsite-checkout` branch, PR #271). The guide's checkout section, rewritten on that branch for the two checkout modes and shipping zones, was corrected for the review fixes: leaner on-site session stash with a 23 h expiry, `payment_intent.payment_method` expansion so `checkout.completed` records the real payment method, and the destination re-resolved on `GET /checkout` instead of trusting the stash.

## 2026-07-20

* **Creation**: [Category Retitles (W1)](/seo/category-retitles-2026-07-20.md), applied to production and live-verified same day: 23 `meta_title` rewrites (17 leaf + 6 parent) and 18 new `meta_description` values, so every category now has both fields written. Targeting was revised against GSC evidence: lead with the product noun searchers actually type, add "Wholesale UK"/"Bulk UK" only where it does not displace a term with real impressions.
* **Update**: Question-style category H2 (plan W1, [roadmap](/plans/2026-07-07-b2b-organic-roadmap.md) Task 7) **dropped**. `category_question_heading` was not an unrendered oversight: it was removed deliberately in March (`d60461d5`) and is guarded by a "does not render question heading" test. Corrected in the [B2B plan](/seo/b2b-organic-growth-plan-2026-07.md), the [audit](/seo/seo-audit-2026-07-19.md), and the roadmap task (which now carries a process note: a grep proves absence of use, not absence of intent).

## 2026-07-19

* **Creation**: [SEO Audit 2026-07-19](/seo/seo-audit-2026-07-19.md). Full audit + the Jul 17 GSC measurement checkpoint (28-day manual export). Organic clicks recovered to the ~10/day pre-rename baseline; the deep Datafa.st "Google" V was non-organic (Ads bundled in the referrer). B1 buying-guide gate FAILED (B2 stays paused); B0 meta rewrite measured neutral; high-intent buckets still ~0 clicks; old renamed URLs still out-rank their replacements (equity transfer incomplete). Datafa.st: flat MoM, returning share doubled, funnel goals firing again (purchase captures 12/27 payments). Scoreboard: W0.2/W0.3/W0.4/W5-CTA done; W1 5/30, W3/W6/W7 open. New: merchant-feed taxonomy gap for renamed categories, Outrank drafts at 89, quick_add URLs collecting impressions.
* **Update**: [SEO Backlog](/seo/backlog.md) re-prioritised per the measurement: B0 closed (neutral), B1 resolved (gate failed), B5 resolved (structural), B0b partial (CTA targets done), B3/B4 escalated (89 drafts). SEO index updated.
* **Creation**: [Napkins "for Restaurants & Cafés" Content](/seo/napkins-restaurants-content-2026-07-19.md), applied to production and live-verified same day: napkins category retitle + guide section + usage-rate FAQ, and a first-screen category link in /blog/paper-napkins. Executes the audit's proven play (`paper napkins for restaurants` pos 4.6 / 0 clicks held by the blog URL); measure at the ~2026-08-16 pull.

## 2026-07-08

* **Creation**: Adopted OKF v0.1 for `docs/` (Phase 1). Added bundle conventions to repo `CLAUDE.md`, created this log, the root [index](/index.md), and the [SEO index](/seo/index.md).
* **Update**: Added frontmatter (`type`, `description`, `status`, `timestamp`) to all 8 documents in `/seo/`. The three `move2-*` drafts are marked `shipped` (applied to production 2026-06-19). Directories outside `/seo/` are not yet retrofitted.
* **Creation**: Added `bin/docs_lint` (frontmatter, index coverage, bundle-link resolution, log format) and a `docs_lint` CI job, so structural drift in the curated bundle fails the build.
* **Update**: Phase 2 retrofit. Frontmatter and status across `/plans/` (43 docs, statuses researched against git history and the current codebase), `/reports/`, and `/proposals/`; indexes for all three. The 2025 partnership proposal and term sheet are marked superseded by the retainer proposal; the tier1 white-label playbook was already marked superseded in its body and now carries matching frontmatter.
* **Update**: [Keyword Targeting Strategy](/seo/keyword-targeting-strategy.md) marked superseded by the [B2B organic growth plan](/seo/b2b-organic-growth-plan-2026-07.md) (owner confirmed). Execution status of the [90-day social media plan](/reports/social-media-90-day-plan.md) is unconfirmed; revisit at the July 17 measurement session. Root index worklog entry de-linked (worklogs are gitignored, local only).
* **Creation**: New `/runbooks/` area: [deploying](/runbooks/deploying.md), [credentials](/runbooks/credentials.md), [stripe-checkout](/runbooks/stripe-checkout.md), [datafast-tracking](/runbooks/datafast-tracking.md). Lint expanded to all curated directories with recursive index coverage.
