# Tasks: Blog Foundation

**Input**: Design documents from `/specs/001-blog-foundation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per constitution requirement (Test-First Development is NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Includes exact file paths in descriptions

## Path Conventions

Rails application structure at repository root:
- Models: `app/models/`
- Controllers: `app/controllers/`
- Views: `app/views/`
- Helpers: `app/helpers/`
- Tests: `test/`
- Fixtures: `test/fixtures/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add Redcarpet gem and create database migration

- [x] T001 Add redcarpet gem to Gemfile and run bundle install
- [x] T002 Generate migration for blog_posts table in db/migrate/
- [x] T003 Run migration with `rails db:migrate`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create fixtures, model, helper, and routes that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create test fixtures in test/fixtures/blog_posts.yml (published_post, draft_post, second_published_post)
- [x] T005 [P] Write model tests (failing) in test/models/blog_post_test.rb
- [x] T006 [P] Write helper tests (failing) in test/helpers/markdown_helper_test.rb
- [x] T007 Implement BlogPost model in app/models/blog_post.rb (validations, callbacks, scopes, methods)
- [x] T008 Implement MarkdownHelper in app/helpers/markdown_helper.rb (render_markdown method)
- [x] T009 Verify model and helper tests pass with `rails test test/models/blog_post_test.rb test/helpers/markdown_helper_test.rb`
- [x] T010 Add blog routes to config/routes.rb (public and admin)

**Checkpoint**: Foundation ready - BlogPost model works, Markdown renders, routes exist

---

## Phase 3: User Story 1 - View Blog Posts (Priority: P1) 🎯 MVP

**Goal**: Site visitors can browse and read published blog posts at `/blog`

**Independent Test**: Create a blog post in database, visit `/blog`, see listing, click through to full post

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T011 [P] [US1] Write controller tests (failing) for BlogPostsController#index in test/controllers/blog_posts_controller_test.rb
- [x] T012 [P] [US1] Write controller tests (failing) for BlogPostsController#show in test/controllers/blog_posts_controller_test.rb

### Implementation for User Story 1

- [x] T013 [US1] Implement BlogPostsController with index and show actions in app/controllers/blog_posts_controller.rb
- [x] T014 [P] [US1] Create blog listing view in app/views/blog_posts/index.html.erb (cards with title, excerpt, date)
- [x] T015 [P] [US1] Create single post view in app/views/blog_posts/show.html.erb (rendered Markdown, meta tags)
- [x] T016 [US1] Verify public controller tests pass with `rails test test/controllers/blog_posts_controller_test.rb`

**Checkpoint**: Visitors can view published posts at `/blog` and `/blog/:slug`

---

## Phase 4: User Story 2 - Create Blog Posts (Priority: P1)

**Goal**: Administrators can create new blog posts via admin interface

**Independent Test**: Log into admin, navigate to `/admin/blog_posts/new`, fill form, submit, verify post appears

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T017 [P] [US2] Write controller tests (failing) for Admin::BlogPostsController#index in test/controllers/admin/blog_posts_controller_test.rb
- [x] T018 [P] [US2] Write controller tests (failing) for Admin::BlogPostsController#new and #create in test/controllers/admin/blog_posts_controller_test.rb

### Implementation for User Story 2

- [x] T019 [US2] Create Admin::BlogPostsController with index, new, create actions in app/controllers/admin/blog_posts_controller.rb
- [x] T020 [P] [US2] Create admin listing view in app/views/admin/blog_posts/index.html.erb (table with status badges)
- [x] T021 [P] [US2] Create admin form partial in app/views/admin/blog_posts/_form.html.erb (title, body, excerpt, published, SEO fields)
- [x] T022 [P] [US2] Create new post view in app/views/admin/blog_posts/new.html.erb (wraps form)
- [x] T023 [US2] Verify admin create tests pass with `rails test test/controllers/admin/blog_posts_controller_test.rb`

**Checkpoint**: Admins can create new posts, posts appear in admin listing and public blog (if published)

---

## Phase 5: User Story 3 - Edit Blog Posts (Priority: P2)

**Goal**: Administrators can edit existing blog posts to update content or change publication status

**Independent Test**: Create a post, navigate to edit, change title, save, verify changes appear

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T024 [P] [US3] Write controller tests (failing) for Admin::BlogPostsController#edit and #update in test/controllers/admin/blog_posts_controller_test.rb

### Implementation for User Story 3

- [x] T025 [US3] Add edit and update actions to Admin::BlogPostsController in app/controllers/admin/blog_posts_controller.rb
- [x] T026 [US3] Create edit post view in app/views/admin/blog_posts/edit.html.erb (wraps form)
- [x] T027 [US3] Verify admin edit tests pass with `rails test test/controllers/admin/blog_posts_controller_test.rb`

**Checkpoint**: Admins can edit posts, changes reflect on public blog

---

## Phase 6: User Story 4 - Delete Blog Posts (Priority: P3)

**Goal**: Administrators can delete blog posts that are no longer relevant

**Independent Test**: Create a post, delete via admin, verify 404 on former URL

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T028 [P] [US4] Write controller tests (failing) for Admin::BlogPostsController#destroy in test/controllers/admin/blog_posts_controller_test.rb

### Implementation for User Story 4

- [x] T029 [US4] Add destroy action to Admin::BlogPostsController in app/controllers/admin/blog_posts_controller.rb
- [x] T030 [US4] Add delete button/confirmation to admin listing in app/views/admin/blog_posts/index.html.erb
- [x] T031 [US4] Verify admin destroy tests pass with `rails test test/controllers/admin/blog_posts_controller_test.rb`

**Checkpoint**: All admin CRUD operations work, full blog lifecycle complete

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: SEO compliance, code quality, and final validation

- [x] T032 [P] Add blog posts to sitemap in app/services/sitemap_generator_service.rb
- [x] T033 [P] Add canonical URL and meta tags to blog show view in app/views/blog_posts/show.html.erb
- [x] T034 Run RuboCop and fix any violations with `rubocop`
- [x] T035 Run Brakeman security check with `brakeman`
- [x] T036 Run full test suite with `rails test`
- [x] T037 Manual verification per quickstart.md checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phases 3-6)**: All depend on Foundational phase completion
  - US1 and US2 are both P1 - can proceed in parallel
  - US3 depends on US2 (needs admin controller structure)
  - US4 depends on US2 (needs admin controller structure)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

| Story | Priority | Can Start After | Dependencies on Other Stories |
|-------|----------|-----------------|-------------------------------|
| US1 - View Posts | P1 | Phase 2 | None (public-facing only) |
| US2 - Create Posts | P1 | Phase 2 | None (admin-facing only) |
| US3 - Edit Posts | P2 | US2 | Needs Admin::BlogPostsController from US2 |
| US4 - Delete Posts | P3 | US2 | Needs Admin::BlogPostsController from US2 |

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Controller before views
3. Views can be created in parallel once controller exists
4. Story complete when its tests pass

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T005, T006 can run in parallel (different test files)

**Phase 3 (US1)**:
- T011, T012 can run in parallel (same file, different tests - but mark [P])
- T014, T015 can run in parallel (different view files)

**Phase 4 (US2)**:
- T017, T018 can run in parallel (same file, different tests - but mark [P])
- T020, T021, T022 can run in parallel (different view files)

**Phase 7 (Polish)**:
- T032, T033 can run in parallel (different files)

---

## Parallel Example: Phase 2 - Foundational

```bash
# Launch model and helper tests together:
Task: "Write model tests (failing) in test/models/blog_post_test.rb"
Task: "Write helper tests (failing) in test/helpers/markdown_helper_test.rb"
```

## Parallel Example: User Story 1 Views

```bash
# After controller is done, launch views together:
Task: "Create blog listing view in app/views/blog_posts/index.html.erb"
Task: "Create single post view in app/views/blog_posts/show.html.erb"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup (gems, migration)
2. Complete Phase 2: Foundational (model, helper, routes)
3. Complete Phase 3: User Story 1 (public viewing)
4. Complete Phase 4: User Story 2 (admin create)
5. **STOP and VALIDATE**: Blog is functional - can view and create posts
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Model and routes ready
2. Add US1 → Visitors can view posts → Demo
3. Add US2 → Admins can create posts → Demo (MVP complete!)
4. Add US3 → Admins can edit posts → Demo
5. Add US4 → Admins can delete posts → Demo (Full feature)
6. Polish → SEO, code quality → Deploy

### Parallel Team Strategy

With two developers:

1. Both complete Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (public side)
   - Developer B: User Story 2 (admin side)
3. After both complete:
   - Developer A: User Story 3 (edit - extends admin)
   - Developer B: User Story 4 (delete - extends admin)
4. Both: Polish phase

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests FAIL before implementing (Red phase)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution requires fixtures - use test/fixtures/blog_posts.yml not inline Model.create!

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 37 |
| **Setup Tasks** | 3 |
| **Foundational Tasks** | 7 |
| **US1 Tasks** | 6 |
| **US2 Tasks** | 7 |
| **US3 Tasks** | 4 |
| **US4 Tasks** | 4 |
| **Polish Tasks** | 6 |
| **Parallelizable** | 18 (marked [P]) |

**MVP Scope**: Phases 1-4 (US1 + US2) = 23 tasks
**Full Feature**: All phases = 37 tasks
