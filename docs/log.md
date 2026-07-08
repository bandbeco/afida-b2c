# Update Log

## 2026-07-08

* **Creation**: Adopted OKF v0.1 for `docs/` (Phase 1). Added bundle conventions to repo `CLAUDE.md`, created this log, the root [index](/index.md), and the [SEO index](/seo/index.md).
* **Update**: Added frontmatter (`type`, `description`, `status`, `timestamp`) to all 8 documents in `/seo/`. The three `move2-*` drafts are marked `shipped` (applied to production 2026-06-19). Directories outside `/seo/` are not yet retrofitted.
* **Creation**: Added `bin/docs_lint` (frontmatter, index coverage, bundle-link resolution, log format) and a `docs_lint` CI job, so structural drift in the curated bundle fails the build.
* **Update**: Phase 2 retrofit. Frontmatter and status across `/plans/` (43 docs, statuses researched against git history and the current codebase), `/reports/`, and `/proposals/`; indexes for all three. The 2025 partnership proposal and term sheet are marked superseded by the retainer proposal; the tier1 white-label playbook was already marked superseded in its body and now carries matching frontmatter.
* **Update**: [Keyword Targeting Strategy](/seo/keyword-targeting-strategy.md) marked superseded by the [B2B organic growth plan](/seo/b2b-organic-growth-plan-2026-07.md) (owner confirmed). Execution status of the [90-day social media plan](/reports/social-media-90-day-plan.md) is unconfirmed; revisit at the July 17 measurement session. Root index worklog entry de-linked (worklogs are gitignored, local only).
* **Creation**: New `/runbooks/` area: [deploying](/runbooks/deploying.md), [credentials](/runbooks/credentials.md), [stripe-checkout](/runbooks/stripe-checkout.md), [datafast-tracking](/runbooks/datafast-tracking.md). Lint expanded to all curated directories with recursive index coverage.
