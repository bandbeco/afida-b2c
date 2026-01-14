# Implementation Plan: Blog Foundation

**Branch**: `001-blog-foundation` | **Date**: 2026-01-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-blog-foundation/spec.md`

## Summary

Add a simple Markdown-based blog foundation to the Afida e-commerce site. This includes a `BlogPost` model with slug-based URLs, public listing/show pages at `/blog`, admin CRUD at `/admin/blog_posts`, and Markdown rendering via the Redcarpet gem. The blog follows existing Rails 8 + Hotwire patterns established in the codebase.

## Technical Context

**Language/Version**: Ruby 3.4.7 / Rails 8.1.1
**Primary Dependencies**: Redcarpet (Markdown rendering), existing TailwindCSS 4 + DaisyUI stack
**Storage**: PostgreSQL (primary database, consistent with existing models)
**Testing**: Minitest with fixtures (per constitution requirements)
**Target Platform**: Web (Rails server-rendered with Hotwire)
**Project Type**: Web application (monolithic Rails)
**Performance Goals**: Blog posts load in under 2 seconds (SC-002)
**Constraints**: Must follow existing admin patterns, SEO best practices per constitution
**Scale/Scope**: Simple single-author blog, ~10 posts per page pagination

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Test-First Development** | ✅ COMPLIANT | Tests will be written first using fixtures |
| **II. SEO & Structured Data** | ✅ COMPLIANT | Meta tags, canonical URLs, sitemap inclusion planned |
| **III. Performance & Scalability** | ✅ COMPLIANT | Eager loading for blog post queries, Markdown caching if needed |
| **IV. Security & Payment Integrity** | ✅ COMPLIANT | Markdown HTML sanitization prevents XSS |
| **V. Code Quality & Maintainability** | ✅ COMPLIANT | Follows existing patterns, RuboCop compliance |

**Technology Standards Check**:
- ✅ Rails 8.x with PostgreSQL
- ✅ Vite + TailwindCSS + DaisyUI for frontend
- ✅ Hotwire for navigation (no client-side state frameworks)
- ✅ No GraphQL (standard Rails routes)

## Project Structure

### Documentation (this feature)

```text
specs/001-blog-foundation/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (routes)
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── models/
│   └── blog_post.rb                    # New model
├── controllers/
│   ├── blog_posts_controller.rb        # Public controller
│   └── admin/
│       └── blog_posts_controller.rb    # Admin controller
├── views/
│   ├── blog_posts/
│   │   ├── index.html.erb              # Public listing
│   │   └── show.html.erb               # Single post
│   └── admin/
│       └── blog_posts/
│           ├── index.html.erb          # Admin listing
│           ├── new.html.erb            # New post
│           ├── edit.html.erb           # Edit post
│           └── _form.html.erb          # Shared form
├── helpers/
│   └── markdown_helper.rb              # Markdown rendering

db/
└── migrate/
    └── XXXXXXX_create_blog_posts.rb    # Migration

test/
├── models/
│   └── blog_post_test.rb               # Model tests
├── controllers/
│   ├── blog_posts_controller_test.rb   # Public controller tests
│   └── admin/
│       └── blog_posts_controller_test.rb
├── helpers/
│   └── markdown_helper_test.rb
└── fixtures/
    └── blog_posts.yml                  # Test fixtures
```

**Structure Decision**: Follows existing Rails structure exactly. New files integrate into established directories. Admin controller inherits from `Admin::ApplicationController` for authentication.

## Complexity Tracking

> No violations identified. Feature follows existing patterns without introducing complexity.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
