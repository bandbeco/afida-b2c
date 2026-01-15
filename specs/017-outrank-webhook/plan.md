# Implementation Plan: Outrank Webhook Integration

**Branch**: `017-outrank-webhook` | **Date**: 2026-01-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-outrank-webhook/spec.md`

## Summary

Implement a webhook endpoint to receive blog articles from Outrank.so's SEO content platform. The system authenticates requests using Bearer tokens, processes article batches, maps Outrank fields to existing BlogPost model, downloads cover images, and creates posts as drafts for admin review. Key features include idempotency via Outrank's unique article ID and batch processing support.

## Technical Context

**Language/Version**: Ruby 3.4.7 / Rails 8.1.1
**Primary Dependencies**: Active Storage (images), Rails credentials (token storage)
**Storage**: PostgreSQL (existing BlogPost, BlogCategory models)
**Testing**: Minitest with fixtures (per constitution)
**Target Platform**: Rails web application (existing Afida e-commerce platform)
**Project Type**: Web application - adding API endpoint to existing Rails app
**Performance Goals**: Process webhook within 30 seconds (per SC-001)
**Constraints**: Must use existing BlogPost model structure; Bearer token auth; HTTPS required
**Scale/Scope**: Single articles to batch of multiple articles per webhook

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Test-First Development** | ✅ PASS | Tests will be written before implementation; fixtures will be used |
| **II. SEO & Structured Data** | ✅ N/A | Internal API endpoint, not public-facing page |
| **III. Performance & Scalability** | ✅ PASS | Webhook processing is synchronous; image download can timeout gracefully |
| **IV. Security & Payment Integrity** | ✅ PASS | Bearer token authentication; credentials in Rails encrypted credentials; input validation |
| **V. Code Quality & Maintainability** | ✅ PASS | Standard Rails patterns; service object for webhook processing |

**Technology Constraints Check**:
- ✅ No client-side frameworks (webhook is backend-only)
- ✅ REST API patterns (POST endpoint)
- ✅ PostgreSQL (existing database)
- ✅ Active Storage (existing image handling)

**All gates pass. Proceeding to Phase 0.**

## Project Structure

### Documentation (this feature)

```text
specs/017-outrank-webhook/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── webhook-api.md   # Webhook endpoint contract
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── api/
│       └── webhooks/
│           └── outrank_controller.rb    # Webhook endpoint
├── services/
│   └── outrank/
│       ├── webhook_processor.rb         # Main processing service
│       ├── article_importer.rb          # Single article import logic
│       └── image_downloader.rb          # Cover image download
└── models/
    ├── blog_post.rb                     # Existing (add outrank_id)
    └── blog_category.rb                 # Existing (no changes)

db/
└── migrate/
    └── xxx_add_outrank_id_to_blog_posts.rb

config/
└── routes.rb                            # Add webhook route

test/
├── controllers/
│   └── api/
│       └── webhooks/
│           └── outrank_controller_test.rb
├── services/
│   └── outrank/
│       ├── webhook_processor_test.rb
│       ├── article_importer_test.rb
│       └── image_downloader_test.rb
└── fixtures/
    └── blog_posts.yml                   # Add outrank_id fixtures
```

**Structure Decision**: Follows existing Rails conventions. Webhook controller namespaced under `Api::Webhooks`. Service objects in `Outrank` module to encapsulate business logic and keep controller thin.

## Complexity Tracking

> No violations identified. Implementation follows standard Rails patterns.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *None* | - | - |
