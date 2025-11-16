# Tasks: AI SEO Engine

**Input**: Design documents from `/specs/006-ai-seo-engine/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/admin_api.yml

**Tests**: Following TDD per constitution - tests written FIRST, must FAIL before implementation

**Organization**: Tasks grouped by user story (P1-P3) to enable independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1=Opportunity Discovery, US2=Content Generation, US3=Performance Tracking, US4=Budget Management)
- Include exact file paths in descriptions

## Path Conventions

Rails engine structure: `engines/seo_ai_engine/`
Host app integration: `app/`, `config/`, `test/`

---

## Phase 1: Setup (Rails Engine Infrastructure)

**Purpose**: Initialize mountable Rails engine and configure dependencies

- [ ] T001 Generate Rails engine with `rails plugin new engines/seo_ai_engine --mountable --database=postgresql`
- [ ] T002 [P] Add dependencies to engines/seo_ai_engine/seo_ai_engine.gemspec (`ruby-llm`, `google-apis-webmasters_v3`, `googleauth`, `serpapi`)
- [ ] T003 [P] Configure Rails credentials for API keys (Google OAuth, SerpAPI, Anthropic) using `rails credentials:edit`
- [ ] T004 Create engine configuration in engines/seo_ai_engine/lib/seo_ai_engine.rb with `SeoAi.configure` block
- [ ] T005 Mount engine in host app config/routes.rb at `/seo_ai`

---

## Phase 2: Foundational (Database & Core Infrastructure)

**Purpose**: Core database schema and service infrastructure that BLOCKS all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create migration 001_create_seo_ai_opportunities.rb in engines/seo_ai_engine/db/migrate/
- [ ] T007 [P] Create migration 002_create_seo_ai_content_briefs.rb
- [ ] T008 [P] Create migration 003_create_seo_ai_content_drafts.rb
- [ ] T009 [P] Create migration 004_create_seo_ai_content_items.rb
- [ ] T010 [P] Create migration 005_create_seo_ai_performance_snapshots.rb
- [ ] T011 [P] Create migration 006_create_seo_ai_budget_tracking.rb
- [ ] T012 Run migrations with `cd engines/seo_ai_engine && rails db:migrate`
- [ ] T013 [P] Create base SeoAi::ApplicationController in engines/seo_ai_engine/app/controllers/seo_ai/application_controller.rb
- [ ] T014 [P] Setup VCR for API testing in engines/seo_ai_engine/test/test_helper.rb

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Discover High-Value SEO Opportunities (Priority: P1) 🎯 MVP

**Goal**: Automatically identify SEO opportunities from Google Search Console + SerpAPI, score 0-100, display in admin dashboard

**Independent Test**: Run daily discovery job, verify opportunities table populated with scored keywords, view in dashboard at /seo_ai/admin/opportunities

### Tests for User Story 1 (TDD - Write FIRST, Ensure FAIL)

- [ ] T015 [P] [US1] Model test for Opportunity validations in engines/seo_ai_engine/test/models/seo_ai/opportunity_test.rb
- [ ] T016 [P] [US1] Model test for Opportunity scopes (`high_priority`, `pending`) in engines/seo_ai_engine/test/models/seo_ai/opportunity_test.rb
- [ ] T017 [P] [US1] Service test for OpportunityScorer algorithm in engines/seo_ai_engine/test/services/seo_ai/opportunity_scorer_test.rb
- [ ] T018 [P] [US1] Service test for GscClient (with VCR cassette) in engines/seo_ai_engine/test/services/seo_ai/gsc_client_test.rb
- [ ] T019 [P] [US1] Service test for SerpClient (with VCR cassette) in engines/seo_ai_engine/test/services/seo_ai/serp_client_test.rb
- [ ] T020 [P] [US1] Job test for OpportunityDiscoveryJob in engines/seo_ai_engine/test/jobs/seo_ai/opportunity_discovery_job_test.rb
- [ ] T021 [P] [US1] Controller test for Admin::OpportunitiesController#index in engines/seo_ai_engine/test/controllers/seo_ai/admin/opportunities_controller_test.rb
- [ ] T022 [P] [US1] Controller test for Admin::OpportunitiesController#dismiss in engines/seo_ai_engine/test/controllers/seo_ai/admin/opportunities_controller_test.rb
- [ ] T023 [US1] System test for opportunity dashboard workflow in engines/seo_ai_engine/test/system/admin/opportunities_test.rb

### Implementation for User Story 1

- [ ] T024 [US1] Create Opportunity model in engines/seo_ai_engine/app/models/seo_ai/opportunity.rb (validations, scopes, state enum)
- [ ] T025 [P] [US1] Implement GscClient service in engines/seo_ai_engine/app/services/seo_ai/gsc_client.rb (OAuth, search_analytics method)
- [ ] T026 [P] [US1] Implement SerpClient service in engines/seo_ai_engine/app/services/seo_ai/serp_client.rb (analyze_keyword method)
- [ ] T027 [US1] Implement OpportunityScorer service in engines/seo_ai_engine/app/services/seo_ai/opportunity_scorer.rb (scoring algorithm: volume 40%, competition 30%, relevance 20%, gap 10%)
- [ ] T028 [US1] Implement OpportunityDiscoveryJob in engines/seo_ai_engine/app/jobs/seo_ai/opportunity_discovery_job.rb (GSC → SerpAPI → Scorer → create Opportunities)
- [ ] T029 [US1] Create Admin::OpportunitiesController in engines/seo_ai_engine/app/controllers/seo_ai/admin/opportunities_controller.rb (index, dismiss actions)
- [ ] T030 [P] [US1] Create index view in engines/seo_ai_engine/app/views/seo_ai/admin/opportunities/index.html.erb (table with filters, scores, actions)
- [ ] T031 [US1] Add engine routes in engines/seo_ai_engine/config/routes.rb (namespace :admin, resources :opportunities)
- [ ] T032 [US1] Schedule OpportunityDiscoveryJob daily at 3am in host app config (using Solid Queue)

**Checkpoint**: User Story 1 complete - can discover opportunities, view dashboard, dismiss irrelevant keywords

---

## Phase 4: User Story 2 - Generate Content Drafts from Opportunities (Priority: P2)

**Goal**: AI generates blog post drafts (1,500-2,000 words) with 3-stage workflow (Strategist → Writer → Reviewer), user reviews and approves before publishing

**Independent Test**: Select opportunity, click "Generate Content", wait for job, view draft in /seo_ai/admin/content_drafts, approve to publish

### Tests for User Story 2 (TDD - Write FIRST, Ensure FAIL)

- [ ] T033 [P] [US2] Model test for ContentBrief in engines/seo_ai_engine/test/models/seo_ai/content_brief_test.rb
- [ ] T034 [P] [US2] Model test for ContentDraft (validations, quality_score >= 50) in engines/seo_ai_engine/test/models/seo_ai/content_draft_test.rb
- [ ] T035 [P] [US2] Model test for ContentItem in engines/seo_ai_engine/test/models/seo_ai/content_item_test.rb
- [ ] T036 [P] [US2] Service test for LlmClient (with VCR) in engines/seo_ai_engine/test/services/seo_ai/llm_client_test.rb
- [ ] T037 [P] [US2] Service test for ContentStrategist in engines/seo_ai_engine/test/services/seo_ai/content_strategist_test.rb
- [ ] T038 [P] [US2] Service test for ContentWriter in engines/seo_ai_engine/test/services/seo_ai/content_writer_test.rb
- [ ] T039 [P] [US2] Service test for ContentReviewer in engines/seo_ai_engine/test/services/seo_ai/content_reviewer_test.rb
- [ ] T040 [P] [US2] Job test for ContentGenerationJob in engines/seo_ai_engine/test/jobs/seo_ai/content_generation_job_test.rb
- [ ] T041 [P] [US2] Controller test for Admin::ContentDraftsController in engines/seo_ai_engine/test/controllers/seo_ai/admin/content_drafts_controller_test.rb
- [ ] T042 [P] [US2] Controller test for Admin::ContentItemsController in engines/seo_ai_engine/test/controllers/seo_ai/admin/content_items_controller_test.rb
- [ ] T043 [US2] System test for draft review and approval workflow in engines/seo_ai_engine/test/system/admin/content_drafts_test.rb

### Implementation for User Story 2

- [ ] T044 [P] [US2] Create ContentBrief model in engines/seo_ai_engine/app/models/seo_ai/content_brief.rb (belongs_to opportunity)
- [ ] T045 [P] [US2] Create ContentDraft model in engines/seo_ai_engine/app/models/seo_ai/content_draft.rb (belongs_to brief, reviewed_by user, quality_score validation)
- [ ] T046 [P] [US2] Create ContentItem model in engines/seo_ai_engine/app/models/seo_ai/content_item.rb (belongs_to draft, slug, SEO fields)
- [ ] T047 [US2] Implement LlmClient service in engines/seo_ai_engine/app/services/seo_ai/llm_client.rb (ruby-llm wrapper, timeout 120s, retry 3×)
- [ ] T048 [US2] Implement ContentStrategist in engines/seo_ai_engine/app/services/seo_ai/content_strategist.rb (Claude prompt: competitor analysis → content brief)
- [ ] T049 [US2] Implement ContentWriter in engines/seo_ai_engine/app/services/seo_ai/content_writer.rb (Claude prompt: brief → 1,500-2,000 word markdown draft)
- [ ] T050 [US2] Implement ContentReviewer in engines/seo_ai_engine/app/services/seo_ai/content_reviewer.rb (Claude prompt: quality score 0-100, flag issues)
- [ ] T051 [US2] Implement ContentGenerationJob in engines/seo_ai_engine/app/jobs/seo_ai/content_generation_job.rb (3-stage: Strategist → Writer → Reviewer)
- [ ] T052 [US2] Create Admin::ContentDraftsController in engines/seo_ai_engine/app/controllers/seo_ai/admin/content_drafts_controller.rb (index, show, approve, reject)
- [ ] T053 [US2] Create Admin::ContentItemsController in engines/seo_ai_engine/app/controllers/seo_ai/admin/content_items_controller.rb (index, show)
- [ ] T054 [P] [US2] Create content_drafts views in engines/seo_ai_engine/app/views/seo_ai/admin/content_drafts/ (index, show with markdown preview, approve/reject buttons)
- [ ] T055 [P] [US2] Create content_items views in engines/seo_ai_engine/app/views/seo_ai/admin/content_items/ (index, show)
- [ ] T056 [US2] Add "Generate Content" button to opportunities#show that queues ContentGenerationJob
- [ ] T057 [US2] Add routes for content_drafts and content_items in engines/seo_ai_engine/config/routes.rb

**Checkpoint**: User Story 2 complete - can generate AI drafts, review quality scores, approve to publish

---

## Phase 5: Host App Blog Integration (Publish Content)

**Purpose**: Display published ContentItem as public blog posts with SEO

- [ ] T058 [P] Create BlogsController in app/controllers/blogs_controller.rb (index, show for SeoAi::ContentItem)
- [ ] T059 [P] Create ArticleHelper in app/helpers/article_helper.rb (Schema.org JSON-LD for blog posts)
- [ ] T060 [P] Create blog views in app/views/blogs/ (index.html.erb, show.html.erb with markdown rendering)
- [ ] T061 Add blog routes in config/routes.rb (`resources :blogs, only: [:index, :show], path: 'blog'`)
- [ ] T062 Integrate ContentItem into SitemapGeneratorService in app/services/sitemap_generator_service.rb
- [ ] T063 [P] Integration test for blog SEO (sitemap, structured data) in test/integration/blog_seo_test.rb
- [ ] T064 [P] System test for public blog display in test/system/blog_display_test.rb

**Checkpoint**: Published content accessible at /blog/:slug with SEO metadata

---

## Phase 6: User Story 3 - Track Content Performance and ROI (Priority: P3)

**Goal**: Weekly GSC performance tracking for published content, display trends and ROI metrics vs £600 agency baseline

**Independent Test**: Publish content, wait 1 week, run PerformanceTrackingJob, view metrics at /seo_ai/admin/performance

### Tests for User Story 3 (TDD - Write FIRST, Ensure FAIL)

- [ ] T065 [P] [US3] Model test for PerformanceSnapshot in engines/seo_ai_engine/test/models/seo_ai/performance_snapshot_test.rb
- [ ] T066 [P] [US3] Job test for PerformanceTrackingJob in engines/seo_ai_engine/test/jobs/seo_ai/performance_tracking_job_test.rb
- [ ] T067 [P] [US3] Controller test for Admin::PerformanceController in engines/seo_ai_engine/test/controllers/seo_ai/admin/performance_controller_test.rb
- [ ] T068 [US3] System test for performance dashboard in engines/seo_ai_engine/test/system/admin/performance_test.rb

### Implementation for User Story 3

- [ ] T069 [US3] Create PerformanceSnapshot model in engines/seo_ai_engine/app/models/seo_ai/performance_snapshot.rb (belongs_to content_item, period dates, metrics)
- [ ] T070 [US3] Implement PerformanceTrackingJob in engines/seo_ai_engine/app/jobs/seo_ai/performance_tracking_job.rb (GSC data → snapshots, calculate trends, flag underperformers)
- [ ] T071 [US3] Create Admin::PerformanceController in engines/seo_ai_engine/app/controllers/seo_ai/admin/performance_controller.rb (index with ROI dashboard)
- [ ] T072 [P] [US3] Create performance views in engines/seo_ai_engine/app/views/seo_ai/admin/performance/ (dashboard with charts, trends, ROI calculator)
- [ ] T073 [US3] Add performance routes in engines/seo_ai_engine/config/routes.rb
- [ ] T074 [US3] Schedule PerformanceTrackingJob weekly (Sunday 3am) in host app config

**Checkpoint**: User Story 3 complete - weekly performance tracking, ROI dashboard showing savings vs agency

---

## Phase 7: User Story 4 - Manage Monthly Budget and API Costs (Priority: P3)

**Goal**: Track API costs, alert at thresholds (£80 warning, £100 alert), enforce rate limits

**Independent Test**: Generate content, verify costs recorded in BudgetTracking, check alerts trigger at thresholds

### Tests for User Story 4 (TDD - Write FIRST, Ensure FAIL)

- [ ] T075 [P] [US4] Model test for BudgetTracking in engines/seo_ai_engine/test/models/seo_ai/budget_tracking_test.rb
- [ ] T076 [P] [US4] Service test for budget tracking logic in engines/seo_ai_engine/test/services/seo_ai/budget_tracker_test.rb
- [ ] T077 [US4] Integration test for cost alerts in engines/seo_ai_engine/test/integration/budget_alerts_test.rb

### Implementation for User Story 4

- [ ] T078 [US4] Create BudgetTracking model in engines/seo_ai_engine/app/models/seo_ai/budget_tracking.rb (monthly aggregates, calculate_totals callback)
- [ ] T079 [US4] Implement BudgetTracker service in engines/seo_ai_engine/app/services/seo_ai/budget_tracker.rb (record costs, check thresholds, send alerts)
- [ ] T080 [US4] Add cost tracking to LlmClient (record llm_cost_gbp after each request)
- [ ] T081 [US4] Add cost tracking to SerpClient (record serpapi_cost_gbp)
- [ ] T082 [US4] Implement AlertMailer in engines/seo_ai_engine/app/mailers/seo_ai/alert_mailer.rb (budget_warning, budget_exceeded)
- [ ] T083 [US4] Add budget enforcement to OpportunityDiscoveryJob (enforce SerpAPI 3/day limit, queue excess)
- [ ] T084 [US4] Add budget enforcement to ContentGenerationJob (enforce max 10 drafts/week)
- [ ] T085 [P] [US4] Add budget dashboard to Admin::PerformanceController (monthly costs, cost per article)

**Checkpoint**: User Story 4 complete - cost tracking, alerts, rate limiting prevents overspend

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Production readiness, security, performance, documentation

- [ ] T086 [P] Add plagiarism check to ContentReviewer (>80% similarity detection, block save)
- [ ] T087 [P] Add product link validation to ContentDraft (verify product_ids exist before save)
- [ ] T088 [P] Implement circuit breaker for Claude API (5 failures → 15min pause) in LlmClient
- [ ] T089 [P] Add OAuth token expiration detection to GscClient (FR-029: email alert, pause discovery)
- [ ] T090 [P] Setup Sidekiq dashboard for job monitoring
- [ ] T091 [P] Add database indexes for performance (see data-model.md)
- [ ] T092 [P] RuboCop pass on all engine code (`cd engines/seo_ai_engine && rubocop`)
- [ ] T093 [P] Brakeman security scan (`brakeman engines/seo_ai_engine/`)
- [ ] T094 [P] Update CLAUDE.md with SEO AI Engine context
- [ ] T095 [P] Create docs/seo-ai-engine-architecture.md (architecture diagram, workflows)
- [ ] T096 Run quickstart.md validation (follow setup steps, verify all works)
- [ ] T097 Final integration test: Discover opportunity → Generate draft → Approve → Publish → Track performance (full workflow end-to-end)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational completion
  - US1 (Opportunity Discovery): Can start after Foundational
  - US2 (Content Generation): Can start after Foundational, integrates with US1 but independently testable
  - Blog Integration (Phase 5): Depends on US2 (needs ContentItem)
  - US3 (Performance Tracking): Can start after Foundational, depends on Blog Integration for published content
  - US4 (Budget Management): Can start after Foundational, integrates with US1+US2 for cost tracking
- **Polish (Phase 8)**: Depends on all user stories

### User Story Independence

- **US1**: Fully independent - discover and score opportunities
- **US2**: Integrates with US1 (uses Opportunity), but testable independently by creating test opportunities
- **US3**: Integrates with ContentItem (from US2 via Blog Integration), testable independently with test content
- **US4**: Integrates with US1+US2 for cost recording, testable independently with mock costs

### Recommended MVP Scope

**Minimum Viable Product = US1 + US2 + Blog Integration**

1. Complete Setup + Foundational (T001-T014)
2. Complete US1: Opportunity Discovery (T015-T032)
3. Complete US2: Content Generation (T033-T057)
4. Complete Blog Integration (T058-T064)
5. **STOP and VALIDATE**: Can discover opportunities, generate drafts, publish blogs
6. Deploy/demo MVP

**Then add incrementally:**
- Add US3 (Performance Tracking) for ROI validation
- Add US4 (Budget Management) for cost control
- Add Polish (Phase 8) for production hardening

### Parallel Opportunities

**Within Setup**: T002, T003 can run in parallel
**Within Foundational**: T007-T011 migrations, T013-T014 controllers/tests can run in parallel
**Within US1 Tests**: T015-T022 all tests can run in parallel
**Within US1 Implementation**: T025-T026 (GscClient + SerpClient), T030 (views) can run in parallel
**Within US2 Tests**: T033-T042 all tests can run in parallel
**Within US2 Implementation**: T044-T046 models, T054-T055 views can run in parallel
**Within Blog Integration**: T058-T060, T063-T064 can run in parallel
**Within US3 Tests**: T065-T067 can run in parallel
**Within US4 Tests**: T075-T076 can run in parallel
**Within Polish**: T086-T095 most tasks can run in parallel

**Between User Stories**: Once Foundational complete, US1, US2 setup (models), US3, US4 can progress in parallel with different team members

---

## Parallel Example: User Story 1

```bash
# Launch all US1 tests in parallel (write these FIRST):
Task T015-T023: All US1 test files (different files, no dependencies)

# Launch US1 parallel implementations:
Task T025: GscClient service
Task T026: SerpClient service
Task T030: Admin views

# Then sequential:
Task T024: Opportunity model (needed by T027)
Task T027: OpportunityScorer (needs model)
Task T028: OpportunityDiscoveryJob (needs all services)
Task T029: OpportunitiesController (needs job)
```

---

## Implementation Strategy

### TDD Workflow (Constitution Requirement)

1. Write test for component FIRST
2. Run test - MUST FAIL (red)
3. Write minimum code to pass (green)
4. Refactor for quality
5. Commit
6. Next task

### MVP First (12-Week Timeline)

**Weeks 1-2**: Setup + Foundational (T001-T014)
**Weeks 3-6**: US1 Opportunity Discovery (T015-T032)
**Weeks 7-10**: US2 Content Generation (T033-T057)
**Week 11**: Blog Integration (T058-T064)
**Week 12**: Testing, bug fixes, demo prep

**Deliverable**: Working system that discovers opportunities and generates blog content

### Incremental Delivery Beyond MVP

**Month 4**: Add US3 Performance Tracking - prove ROI
**Month 5**: Add US4 Budget Management - cost control
**Month 6**: Polish (Phase 8) - production hardening

---

## Notes

- [P] tasks = different files, can run in parallel
- [Story] label maps to user stories (US1-US4)
- TDD required per constitution - tests FIRST, must FAIL
- Each user story independently testable
- Stop at checkpoints to validate story completion
- Commit after each task or logical group
- VCR cassettes for API testing (record real responses once, replay in tests)
- RuboCop and Brakeman must pass before Phase 8 completion

**Total Tasks**: 97 tasks
**MVP Tasks**: 64 tasks (T001-T064)
**Test Tasks**: 29 tasks (TDD)
**Parallel Tasks**: ~40 tasks marked [P]
