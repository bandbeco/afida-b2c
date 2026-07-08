# Update Log

## 2026-07-08

* **Creation**: Adopted OKF v0.1 for `docs/` (Phase 1). Added bundle conventions to repo `CLAUDE.md`, created this log, the root [index](/index.md), and the [SEO index](/seo/index.md).
* **Update**: Added frontmatter (`type`, `description`, `status`, `timestamp`) to all 8 documents in `/seo/`. The three `move2-*` drafts are marked `shipped` (applied to production 2026-06-19). Directories outside `/seo/` are not yet retrofitted.
* **Creation**: Added `bin/docs_lint` (frontmatter, index coverage, bundle-link resolution, log format) and a `docs_lint` CI job, so structural drift in the curated bundle fails the build.
