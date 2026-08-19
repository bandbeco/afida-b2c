---
type: Runbook
description: How to deploy to production and why plain kamal deploy silently fails; boot by version and verify the served HTML.
status: active
timestamp: 2026-08-19
---

# Deploying to Production

## The gotcha

`kamal deploy` aborts on the postgres accessory host (see `config/deploy.yml`; it uses password auth) BEFORE retagging `:latest`. The app then silently keeps serving the OLD image while the command exit can still look fine. Cloudflare returning `cf-cache-status: DYNAMIC` adds to the confusion when checking.

## The procedure

Deploy with the role restricted to web, which skips the failing accessory step entirely:

```
kamal deploy --roles=web
```

(An older version of this runbook prescribed `kamal build push` followed by `kamal app boot --version=<git-sha> --roles=web`; the single command above is the proper form.)

Verify by fetching a page and checking the served HTML actually changed (a fingerprinted asset path, or the specific change you shipped). Never trust the command's exit code alone.

## Related

* Server-rendered content fields (category FAQs, buying guides, metas) are data, not code: writing them to the production DB makes them live immediately with no deploy.
