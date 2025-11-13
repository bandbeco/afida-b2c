# Implementation Plan: Legacy URL Smart Redirects

**Branch**: `001-legacy-url-redirects` | **Date**: 2025-11-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-legacy-url-redirects/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a database-driven redirect system that intercepts legacy product URLs (`/product/*`) from the old afida.com site and redirects them to the new product structure with extracted variant parameters. The system will use Rack middleware for request interception, a PostgreSQL-backed ActiveRecord model for redirect mappings, and handle 63 known legacy URLs with intelligent parameter extraction and normalization.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionDispatch), Rack middleware, PostgreSQL 14+
**Storage**: PostgreSQL 14+ (primary database with `legacy_redirects` table using JSONB for variant parameters)
**Testing**: Rails test suite (Minitest), system tests with Capybara/Selenium, integration tests for middleware
**Target Platform**: Linux server (production), macOS/Linux (development)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: <10ms redirect overhead per request, handle concurrent redirects without performance degradation
**Constraints**: <500ms total redirect time (including database lookup), case-insensitive URL matching, preserve query parameters
**Scale/Scope**: 63 initial legacy URLs (expandable), admin interface for managing redirects, usage analytics tracking

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Test-First Development (TDD)
- [x] **Requirement**: Tests written FIRST, must fail initially (red phase)
- **Application**:
  - Model tests for `LegacyRedirect` (validation, scopes, methods)
  - Middleware tests for redirect logic and edge cases
  - Integration tests for full redirect flow
  - System tests verifying actual HTTP 301 redirects
  - Tests will be written BEFORE implementing model, middleware, or admin controllers

### II. SEO & Structured Data
- [x] **Requirement**: Canonical URLs, meta tags, structured data
- **Application**:
  - 301 redirects preserve SEO authority (core feature requirement)
  - No additional structured data changes needed (products already have Schema.org markup)
  - Redirects maintain existing canonical URL structure

### III. Performance & Scalability
- [x] **Requirement**: Prevent N+1 queries, SQL-based calculations, memoization
- **Application**:
  - Database index on `legacy_path` column for fast lookups (case-insensitive)
  - Single query per redirect request (no N+1 possible)
  - Hit count increment uses SQL UPDATE to avoid race conditions
  - Middleware executes before Rails routing (minimal overhead)

### IV. Security & Payment Integrity
- [x] **Requirement**: No OWASP Top 10 vulnerabilities, input validation, admin authentication
- **Application**:
  - URL path validation to prevent injection attacks
  - Admin interface requires authentication (uses existing admin auth pattern)
  - No user input directly executed (query parameters sanitized by Rails)
  - Brakeman scan will verify no security issues

### V. Code Quality & Maintainability
- [x] **Requirement**: RuboCop passing, explicit scopes, reversible migrations, SRP
- **Application**:
  - RuboCop will pass before commit
  - Migration includes reversible `up`/`down` methods
  - Model uses explicit scopes for active/inactive redirects
  - Single Responsibility: Middleware handles interception, Model handles data, Controller handles admin UI
  - Clear naming: `LegacyRedirect`, `LegacyRedirectMiddleware`, `Admin::LegacyRedirectsController`

**Status**: ✅ ALL GATES PASSED - No violations, no complexity justification needed

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
app/
├── models/
│   └── legacy_redirect.rb                    # ActiveRecord model for redirect mappings
├── middleware/
│   └── legacy_redirect_middleware.rb         # Rack middleware for request interception
├── controllers/
│   └── admin/
│       └── legacy_redirects_controller.rb    # Admin interface for managing redirects
└── views/
    └── admin/
        └── legacy_redirects/
            ├── index.html.erb                # List redirects with stats
            ├── new.html.erb                  # Create new redirect
            ├── edit.html.erb                 # Edit existing redirect
            └── _form.html.erb                # Shared form partial

db/
├── migrate/
│   └── XXXXXX_create_legacy_redirects.rb     # Migration to create table
└── seeds/
    └── legacy_redirects.rb                   # Seed file with 63 initial mappings

lib/
└── tasks/
    └── legacy_redirects.rake                 # Rake tasks for import/export/validation

config/
├── application.rb                            # Register middleware
└── routes.rb                                 # Add admin routes

test/
├── models/
│   └── legacy_redirect_test.rb               # Model validations, scopes, methods
├── middleware/
│   └── legacy_redirect_middleware_test.rb    # Middleware logic and edge cases
├── controllers/
│   └── admin/
│       └── legacy_redirects_controller_test.rb  # Admin CRUD operations
├── integration/
│   └── legacy_redirect_flow_test.rb          # Full redirect flow testing
└── system/
    └── legacy_redirect_system_test.rb        # Browser-based redirect verification
```

**Structure Decision**: Rails web application (monolith). This feature adds:
- 1 model (`LegacyRedirect`)
- 1 middleware (`LegacyRedirectMiddleware`)
- 1 admin controller (`Admin::LegacyRedirectsController`)
- 1 migration
- 1 seed file
- 1 rake task file
- 5 test files (model, middleware, controller, integration, system)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - All constitution principles satisfied without violations.
