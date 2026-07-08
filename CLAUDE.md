# CLAUDE.md

## Development Practices

- Always use TDD (test-driven development). Write failing tests first, then implement the minimum code to make them pass, then refactor. Follow the red-green-refactor cycle.
- Don't ever use inline styles, ever, no exception.
- Never use bold or semibold font weights (no `font-bold`, `font-semibold`, or equivalent).

## docs/ knowledge bundle (OKF)

`docs/` is an [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) bundle: markdown concept documents with YAML frontmatter.

- Every `docs/**/*.md` (except reserved `index.md` and `log.md`) starts with YAML frontmatter. Required: `type` and `description` (one sentence). Recommended: `status` (`active` | `shipped` | `superseded` | `abandoned`), `timestamp` (date of last substantive update), and `superseded_by` (bundle-absolute link) when superseded.
- Type vocabulary: Plan, Report, Research, Playbook, Backlog, Draft, Runbook, Proposal, Worklog. Add a new type only when none fits.
- Cross-link related docs with bundle-absolute markdown links: `/seo/backlog.md` means `docs/seo/backlog.md`.
- Each curated directory has an `index.md` listing every doc with a one-line description; `docs/log.md` records changes newest-first under `## YYYY-MM-DD` headings.
- After any session that creates or changes knowledge under `docs/`: update the touched docs' frontmatter (`timestamp`, `status`), the directory's `index.md`, and `docs/log.md`. When a doc replaces another, mark the old one `superseded` with `superseded_by`; never delete it.
- Curated so far: `seo/`, `plans/`, `reports/`, `proposals/`, `runbooks/` (mirrored in `CURATED_DIRS` in `bin/docs_lint`). `articles/`, `audits/`, `insights/`, `superpowers/` and most root-level docs are not yet retrofitted; when you substantively touch a legacy doc, add frontmatter to it (and extend `CURATED_DIRS` when a directory is fully done) as part of the change.
- `bin/docs_lint` mechanically checks the curated parts of the bundle (frontmatter, index coverage, link resolution); it runs in CI.
