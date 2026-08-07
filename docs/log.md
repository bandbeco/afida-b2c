# Update Log

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
