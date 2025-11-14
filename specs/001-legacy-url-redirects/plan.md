# Implementation Plan: Legacy URL Smart Redirects

**Branch**: `001-legacy-url-redirects` | **Date**: 2025-11-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-legacy-url-redirects/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Seed database with legacy URL redirect mappings from the existing `config/legacy_redirects.csv` file (64 mappings from legacy afida.com URLs to new product structure) and verify redirects work correctly. The infrastructure (LegacyRedirect model, middleware, admin interface) is already implemented. This task focuses on:
1. Parsing the CSV mapping file to extract redirect data
2. Updating the seed file to populate all 64 redirects
3. Running database seeds
4. Testing that redirects work as expected (HTTP 301 to correct product+variant)

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionDispatch), Rack middleware, PostgreSQL 14+
**Storage**: PostgreSQL 14+ (primary database with `legacy_redirects` table using JSONB for variant parameters)
**Testing**: Minitest (Rails default) with system tests, integration tests, model tests, middleware tests
**Target Platform**: Linux server (production), macOS (development)
**Project Type**: Web application (Rails monolith with Hotwire frontend)
**Performance Goals**: <500ms redirect response time, <10ms middleware overhead per request
**Constraints**: Must issue HTTP 301 (permanent redirect) for SEO, case-insensitive URL matching required
**Scale/Scope**: 64 legacy URLs to redirect initially, admin UI for future management

**Current Implementation Status**:
- ✅ Database migration created (`db/migrate/20251113195313_create_legacy_redirects.rb`)
- ✅ LegacyRedirect model (`app/models/legacy_redirect.rb`) with validations, scopes, hit tracking
- ✅ Middleware (`app/middleware/legacy_redirect_middleware.rb`) for intercepting requests
- ✅ Admin controller (`app/controllers/admin/legacy_redirects_controller.rb`) for CRUD operations
- ✅ CSV mapping file (`config/legacy_redirects.csv`) with 64 legacy URL → target mappings
- ✅ Tests created (model, middleware, controller, integration, system)
- ⏳ Seed file (`db/seeds/legacy_redirects.rb`) has placeholder data - needs updating from CSV
- ⏳ Database seeds not yet run
- ⏳ Redirects not yet tested in running application

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Test-First Development (TDD) ✅
**Status**: PASS - Tests already written for the infrastructure
**Evidence**:
- Model tests exist (`test/models/legacy_redirect_test.rb`)
- Middleware tests exist (`test/middleware/legacy_redirect_middleware_test.rb`)
- Controller tests exist (`test/controllers/admin/legacy_redirects_controller_test.rb`)
- Integration tests exist (`test/integration/legacy_redirect_flow_test.rb`)
- System tests exist (`test/system/legacy_redirect_system_test.rb`)

**Remaining Work**: Verify existing tests pass, add seed data validation tests

### II. SEO & Structured Data ✅
**Status**: PASS - Redirects use HTTP 301 (permanent redirect) for SEO
**Evidence**:
- Middleware issues 301 status codes for successful redirects
- Case-insensitive matching prevents duplicate URL issues
- Hit tracking enables analytics for understanding redirect usage
- 404 fallback for unmapped URLs maintains clean SEO

**Remaining Work**: None (SEO requirements met by existing implementation)

### III. Performance & Scalability ✅
**Status**: PASS - Efficient database lookup with minimal overhead
**Evidence**:
- Single database query per redirect lookup (case-insensitive index)
- Hit count increment uses atomic `increment!` operation
- Middleware processes before Rails router (minimal overhead)
- JSONB storage for variant_params enables flexible parameter extraction

**Remaining Work**: Benchmark redirect response time (<500ms goal)

### IV. Security & Payment Integrity ✅
**Status**: PASS - No security concerns for redirect feature
**Evidence**:
- Model validation ensures target products exist before creating redirects
- Admin controller requires authentication (existing Rails auth system)
- No user input processed directly (redirects from database only)
- No SQL injection risk (uses parameterized queries)

**Remaining Work**: Verify admin authentication is enabled in production

### V. Code Quality & Maintainability ✅
**Status**: PASS - Clean, well-structured code following Rails conventions
**Evidence**:
- Model uses scopes (`.active`, `.inactive`, `.most_used`) not default scopes
- Clear separation of concerns (model, middleware, controller)
- Descriptive method names (`find_active_by_path`, `record_hit!`)
- Tests provide documentation of expected behavior

**Remaining Work**: Run RuboCop linter on seed file after updates

**OVERALL STATUS**: ✅ PASS - All constitution principles met by existing implementation

## Project Structure

### Documentation (this feature)

```text
specs/001-legacy-url-redirects/
├── spec.md             # Feature specification (user stories, requirements)
├── plan.md             # This file (implementation plan)
├── research.md         # Phase 0: Technical decisions and approach
├── data-model.md       # Phase 1: Database schema documentation
├── quickstart.md       # Phase 1: Quick reference guide
└── tasks.md            # Phase 2: Task breakdown (created by /speckit.tasks)
```

### Source Code (Rails application root)

```text
app/
├── models/
│   └── legacy_redirect.rb              # ✅ Model with validations, scopes, hit tracking
├── middleware/
│   └── legacy_redirect_middleware.rb   # ✅ Rack middleware for URL interception
└── controllers/
    └── admin/
        └── legacy_redirects_controller.rb  # ✅ Admin CRUD interface

config/
├── initializers/
│   └── legacy_redirect_middleware.rb   # ✅ Middleware registration
└── legacy_redirects.csv                 # ✅ Source mapping file (64 URLs)

db/
├── migrate/
│   └── 20251113195313_create_legacy_redirects.rb  # ✅ Database migration
└── seeds/
    └── legacy_redirects.rb              # ⏳ Seed file (needs updating from CSV)

lib/
├── data/
│   ├── legacy_urls.json                # Legacy URL list for reference
│   └── products.csv                    # Product data for mapping validation
└── tasks/
    └── legacy_redirects.rake           # ✅ Rake tasks for redirect management

test/
├── models/
│   └── legacy_redirect_test.rb         # ✅ Model validation and method tests
├── middleware/
│   └── legacy_redirect_middleware_test.rb  # ✅ Middleware behavior tests
├── controllers/
│   └── admin/
│       └── legacy_redirects_controller_test.rb  # ✅ Controller CRUD tests
├── integration/
│   ├── legacy_redirect_flow_test.rb    # ✅ End-to-end redirect flow
│   └── admin_legacy_redirects_test.rb  # ✅ Admin interface integration
└── system/
    └── legacy_redirect_system_test.rb  # ✅ Browser-based redirect verification
```

**Structure Decision**: Rails web application (Option 2 variant - monolith with Rails conventions). All code follows standard Rails MVC structure with middleware for request interception.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - All constitution principles are met by the existing implementation.
