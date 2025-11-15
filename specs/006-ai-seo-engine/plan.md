# Implementation Plan: AI SEO Engine

**Branch**: `006-ai-seo-engine` | **Date**: 2025-11-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-ai-seo-engine/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a Rails engine (`seo_ai_engine`) that discovers SEO opportunities via Google Search Console and SerpAPI, generates optimized blog content using Claude AI (via `ruby-llm` gem), and tracks performance to replace a £600/month SEO agency with a £90/month automated system. The engine will be mountable, allowing potential future extraction as a standalone SaaS product.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: NEEDS CLARIFICATION - LLM integration gem (`ruby-llm` vs `anthropic-rb`), Google Search Console API client, SerpAPI client
**Storage**: PostgreSQL 14+ (6 new engine tables: opportunities, content_briefs, content_drafts, content_items, performance_snapshots, budget_tracking)
**Testing**: Minitest (Rails default), System tests with Capybara for admin UI, Service object tests for LLM integration
**Target Platform**: Web application (mountable Rails engine)
**Project Type**: Web (Rails engine + host app integration)
**Performance Goals**: NEEDS CLARIFICATION - Background job processing (daily opportunity discovery, weekly performance tracking), API timeout thresholds (Claude 120s, exponential backoff)
**Constraints**: Budget control (<£90/month APIs), Rate limits (SerpAPI 3/day, max 10 drafts/week), Manual approval required (no auto-publishing)
**Scale/Scope**: 20 blog posts in 3 months, 6 database tables, 3-stage LLM workflow (Strategist → Writer → Reviewer), Admin dashboard with 4 main views

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Test-First Development (TDD) ✅ COMPLIANT

**Requirement**: All features MUST follow strict TDD with tests written FIRST before implementation.

**Plan Compliance**:
- ✅ Engine models (Opportunity, ContentBrief, ContentDraft, ContentItem, PerformanceSnapshot, BudgetTracking) will have model tests written first
- ✅ Service objects (ContentStrategist, ContentWriter, ContentReviewer) will have service tests before implementation
- ✅ Admin controllers will have controller tests and system tests before implementation
- ✅ Background jobs (OpportunityDiscoveryJob, PerformanceTrackingJob) will have job tests first
- ✅ API integrations (GSC, SerpAPI, Claude) will have integration tests with VCR for API mocking

**Test Coverage Plan**:
- Model validations and associations
- Service object business logic (scoring algorithm, LLM prompts)
- Controller CRUD operations and access control
- System tests for admin workflows (review draft, approve, publish)
- Integration tests for external APIs with recorded cassettes

### II. SEO & Structured Data ✅ COMPLIANT

**Requirement**: Every public-facing page MUST implement comprehensive SEO.

**Plan Compliance**:
- ✅ Published content items (blogs/guides) will have unique slugs for SEO-friendly URLs
- ✅ Meta tags (meta_title, meta_description) stored per content item (FR-009, FR-014)
- ✅ Schema.org Article structured data required for published content (FR-017)
- ✅ Sitemap integration required (FR-016)
- ✅ Content accessible via public URLs (FR-015): `/blog/:slug`

**Implementation**:
- BlogsController will render published ContentItem with SEO metadata
- SitemapGeneratorService will include published content items
- ArticleHelper will generate Schema.org JSON-LD for blog posts

### III. Performance & Scalability ✅ COMPLIANT

**Requirement**: Application MUST maintain production-grade performance with N+1 query prevention.

**Plan Compliance**:
- ✅ Background jobs for expensive operations (daily discovery, weekly performance tracking)
- ✅ Eager loading planned for ContentDraft associations (opportunity, brief, related products/categories)
- ✅ JSONB columns for metadata to avoid additional tables (competitor_analysis, keyword_positions)
- ✅ Database indexes on frequently queried fields (slug, status, score, published_at)
- ✅ API timeout controls (Claude 120s, exponential backoff max 3 retries)
- ✅ Rate limiting enforced (SerpAPI 3/day, max 10 drafts/week)

**Performance Considerations**:
- Opportunity scoring algorithm runs in SQL where possible
- Weekly performance snapshots use batch processing
- LLM API calls async via background jobs (prevents blocking requests)

### IV. Security & Payment Integrity ✅ COMPLIANT

**Requirement**: Security MUST be built into every layer, no OWASP Top 10 vulnerabilities.

**Plan Compliance**:
- ✅ No payment processing in this feature (existing Stripe integration unchanged)
- ✅ Admin authentication required for engine dashboard (inherits from host app User model)
- ✅ API credentials stored in Rails encrypted credentials (Google OAuth, SerpAPI key, Anthropic key)
- ✅ Input validation on all user inputs (opportunity dismissal, draft edits, admin filters)
- ✅ CSRF protection on all state-changing operations (approve draft, dismiss opportunity)
- ✅ No user-generated content auto-published (manual approval required per FR-012, FR-011)
- ✅ Plagiarism check before saving drafts (FR-031: block >80% similarity)

**Security Measures**:
- OAuth 2.0 for Google Search Console (token expiration detection per FR-029)
- SQL injection prevention via ActiveRecord parameterization
- XSS prevention via Rails sanitization on draft content before display
- Rate limiting prevents API cost attacks

### V. Code Quality & Maintainability ✅ COMPLIANT

**Requirement**: Code MUST maintain high standards, RuboCop MUST pass, no default scopes except documented.

**Plan Compliance**:
- ✅ RuboCop (rails-omakase) will pass before commits
- ✅ No default scopes on engine models (explicit scopes only: `published`, `pending_review`, `high_priority`)
- ✅ Service objects follow Single Responsibility (separate Strategist, Writer, Reviewer)
- ✅ Database migrations reversible
- ✅ Clear naming (ContentBrief not Brief, OpportunityDiscoveryJob not DiscoverJob)
- ✅ Mountable engine architecture allows clean separation from host app

**Quality Standards**:
- Service objects < 100 lines each
- Controllers thin (delegate to services)
- Models handle data/validation, services handle business logic
- Configuration via `SeoAi.configure` block (no magic constants)

### Constitution Compliance Summary

**Status**: ✅ ALL GATES PASSED

No constitution violations. Feature fully complies with:
- TDD workflow (tests first for all components)
- SEO requirements (meta tags, structured data, sitemap)
- Performance standards (background jobs, eager loading, timeouts)
- Security requirements (auth, credentials, no auto-publish, plagiarism check)
- Code quality (RuboCop, no default scopes, SRP, clear naming)

## Project Structure

### Documentation (this feature)

```text
specs/006-ai-seo-engine/
├── spec.md              # Feature specification (created by /speckit.specify)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── admin_api.yml    # OpenAPI spec for admin dashboard endpoints
└── checklists/
    └── requirements.md  # Spec quality checklist (created by /speckit.specify)
```

### Source Code (repository root)

**Structure Decision**: Rails engine + host app integration. The engine will be self-contained in `engines/seo_ai_engine/` with its own models, controllers, services, and tests. The host app will mount the engine and provide integration points (Product, Category, User models).

```text
# Rails Engine (mountable)
engines/seo_ai_engine/
├── app/
│   ├── models/seo_ai/
│   │   ├── opportunity.rb
│   │   ├── content_brief.rb
│   │   ├── content_draft.rb
│   │   ├── content_item.rb
│   │   ├── performance_snapshot.rb
│   │   └── budget_tracking.rb
│   ├── services/seo_ai/
│   │   ├── content_strategist.rb     # Creates content briefs from opportunities
│   │   ├── content_writer.rb         # Generates drafts from briefs
│   │   ├── content_reviewer.rb       # Quality checks drafts
│   │   ├── opportunity_scorer.rb     # Scores opportunities 0-100
│   │   ├── gsc_client.rb             # Google Search Console API wrapper
│   │   ├── serp_client.rb            # SerpAPI wrapper
│   │   └── llm_client.rb             # ruby-llm wrapper (configurable provider)
│   ├── controllers/seo_ai/
│   │   ├── admin/
│   │   │   ├── opportunities_controller.rb
│   │   │   ├── content_drafts_controller.rb
│   │   │   ├── content_items_controller.rb
│   │   │   └── performance_controller.rb
│   │   └── application_controller.rb
│   ├── jobs/seo_ai/
│   │   ├── opportunity_discovery_job.rb    # Daily: GSC + SerpAPI → Opportunities
│   │   ├── content_generation_job.rb       # On-demand: Opportunity → Draft
│   │   └── performance_tracking_job.rb     # Weekly: GSC → PerformanceSnapshot
│   └── views/seo_ai/
│       └── admin/
│           ├── opportunities/
│           ├── content_drafts/
│           ├── content_items/
│           └── performance/
├── config/
│   └── routes.rb                           # Engine routes mounted at /seo_ai
├── db/migrate/
│   ├── 001_create_seo_ai_opportunities.rb
│   ├── 002_create_seo_ai_content_briefs.rb
│   ├── 003_create_seo_ai_content_drafts.rb
│   ├── 004_create_seo_ai_content_items.rb
│   ├── 005_create_seo_ai_performance_snapshots.rb
│   └── 006_create_seo_ai_budget_tracking.rb
├── lib/
│   ├── seo_ai_engine.rb
│   └── seo_ai_engine/engine.rb
└── test/
    ├── models/
    ├── services/
    ├── controllers/
    ├── jobs/
    ├── integration/
    └── system/

# Host App Integration
app/
├── controllers/
│   └── blogs_controller.rb                # Renders published SeoAi::ContentItem
├── helpers/
│   └── article_helper.rb                  # Schema.org JSON-LD for blog posts
└── views/
    └── blogs/
        ├── index.html.erb                  # List published content
        └── show.html.erb                   # Display single blog post

config/
└── routes.rb                               # Mounts engine + defines /blog routes

test/
├── integration/
│   └── blog_seo_test.rb                    # Verify sitemap, structured data
└── system/
    └── blog_display_test.rb                # System test for public blog pages
```

**Rationale**:
- **Engine isolation**: All SEO AI logic contained in `engines/seo_ai_engine/`, allowing future extraction as gem
- **Host app minimal**: Only BlogsController + views to display published content
- **Clear boundaries**: Engine owns all SEO logic, host app owns Product/Category/User models
- **Testability**: Engine tests run independently, host app tests verify integration

## Complexity Tracking

**No violations**. The plan fully complies with all constitution principles.
