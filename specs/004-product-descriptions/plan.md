# Implementation Plan: Product Descriptions Enhancement

**Branch**: `004-product-descriptions` | **Date**: 2025-11-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-product-descriptions/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Replace the single `description` field on products with three separate description fields (short, standard, detailed) to enable contextual content display across different page types. Migrate data from CSV, add fallback logic for missing descriptions, enhance admin interface with character counters, and update all views to display appropriate description types. Implementation follows Rails conventions with TDD, SEO optimization, and performance best practices.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionView, ActiveSupport), Vite Rails, Stimulus, TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing products table, new columns: description_short, description_standard, description_detailed)
**Testing**: Minitest (Rails default), System tests with Capybara + Selenium, RuboCop for linting
**Target Platform**: Web application (server-side rendering with Hotwire)
**Project Type**: Web - Rails monolith with Vite frontend
**Performance Goals**: No N+1 queries, page load time unchanged (<2s), no degradation from additional database columns
**Constraints**: Zero data loss during migration, backward compatible migration (reversible), no breaking changes to existing views during rollout
**Scale/Scope**: ~50 products in CSV, 3 new database columns, 4 view files updated (shop, category, product show, admin form), 1 new Stimulus controller

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Test-First Development (TDD) ✅

**Status**: COMPLIANT

- Migration will have tests verifying data population from CSV
- Model tests for fallback helper methods (short → standard → detailed)
- View tests (system tests) for each description appearing in correct locations
- Admin form tests with character counter Stimulus controller
- All tests written BEFORE implementation code
- Red-Green-Refactor cycle enforced

**Validation**: Tests cover models (fallback logic), controllers (data display), views (correct rendering), and Stimulus (character counters)

### II. SEO & Structured Data ✅

**Status**: COMPLIANT + ENHANCEMENT

- FR-010 explicitly requires using `description_standard` for SEO meta descriptions
- Existing SEO helpers will be updated to use new field
- Product structured data already exists; no changes needed
- Short descriptions on product cards improve CTR from category pages
- Detailed descriptions improve on-page SEO and keyword density

**Validation**: SEO helper tests updated to verify description_standard usage for meta tags

### III. Performance & Scalability ✅

**Status**: COMPLIANT

- New text columns do not introduce N+1 queries (all descriptions loaded with product)
- Fallback logic uses in-memory truncation (no additional DB queries)
- No eager loading changes needed (descriptions part of products table)
- Character counter uses client-side JavaScript (no server roundtrips)
- Migration populates data in batch using `update_columns` (efficient)

**Validation**: Performance constraints met - no degradation from additional columns

### IV. Security & Payment Integrity ✅

**Status**: COMPLIANT

- Text content properly escaped in views using Rails built-in XSS protection
- No user input directly rendered without sanitization
- Admin form uses standard Rails form helpers (CSRF protection built-in)
- CSV migration runs in controlled environment (not user-facing)
- No payment or authentication logic affected

**Validation**: Edge case addresses XSS concerns (HTML/special characters sanitized)

### V. Code Quality & Maintainability ✅

**Status**: COMPLIANT

- Migration is reversible (down method restores old description field)
- Explicit helper methods for fallback logic (no magic behavior)
- Clear naming: `description_short`, `description_standard`, `description_detailed`
- RuboCop will pass before commits
- No default scope changes (Product scope unaffected)
- Single Responsibility: models handle data, views handle display, Stimulus handles interaction

**Validation**: Code follows Rails conventions, migration reversibility tested

### Overall Constitution Compliance: ✅ PASS

All five core principles satisfied. No violations requiring justification. Feature aligns with Rails 8 stack (ActiveRecord, Vite, Stimulus) and existing patterns (SEO helpers, TDD workflow, security practices).

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

### Source Code (Rails Application)

```text
app/
├── models/
│   └── product.rb                                    # Add fallback helper methods
├── controllers/
│   └── admin/
│       └── products_controller.rb                    # No changes needed (strong params auto-permit)
├── views/
│   ├── pages/
│   │   └── shop.html.erb                            # Add description_short to product cards
│   ├── categories/
│   │   └── show.html.erb                            # Add description_short to product cards
│   ├── products/
│   │   └── show.html.erb                            # Add description_standard + description_detailed
│   └── admin/
│       └── products/
│           └── _form.html.erb                       # Add three description fields with counters
├── helpers/
│   └── seo_helper.rb                                # Update meta description logic
└── frontend/
    └── javascript/
        └── controllers/
            └── character_counter_controller.js       # New: Real-time character counting

db/
├── migrate/
│   └── TIMESTAMP_replace_product_description_with_three_fields.rb  # New migration
└── schema.rb                                        # Updated after migration

lib/
└── data/
    └── products.csv                                 # Data source for migration

test/
├── models/
│   └── product_test.rb                              # Test fallback methods
├── controllers/
│   └── admin/
│       └── products_controller_test.rb              # Test form submission
├── system/
│   ├── shop_descriptions_test.rb                    # Test short descriptions on shop page
│   ├── category_descriptions_test.rb                # Test short descriptions on category pages
│   ├── product_descriptions_test.rb                 # Test standard + detailed on product pages
│   └── admin_product_descriptions_test.rb           # Test admin form with character counters
└── helpers/
    └── seo_helper_test.rb                           # Test updated meta description logic
```

**Structure Decision**: Rails monolith with standard MVC structure. Frontend JavaScript uses Stimulus controllers registered in Vite entrypoint. Tests follow Rails conventions (models, controllers, system tests). All changes are additions except for the migration which replaces the `description` column.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - Constitution Check passed for all five principles. No complexity justifications needed.

---

## Post-Design Constitution Re-Check

*Performed after Phase 1 (Design & Contracts) completion*

### Constitution Compliance Review

**Re-evaluation Date**: 2025-11-15

After completing design phase (research.md, data-model.md, contracts/), re-checking all five principles:

#### I. Test-First Development (TDD) ✅

**Status**: STILL COMPLIANT

Design confirms TDD approach:
- Model tests for fallback methods documented in data-model.md
- System tests for all four view types (shop, category, product, admin)
- Migration tests for CSV data population
- Helper tests for SEO meta description logic
- Stimulus controller tests (integration via system tests)

**No changes** from initial check - TDD workflow fully defined in quickstart.md

#### II. SEO & Structured Data ✅

**Status**: STILL COMPLIANT + ENHANCEMENT CONFIRMED

Design enhances SEO:
- SEO helper explicitly updated to use `description_standard` (contracts/README.md)
- Short descriptions improve CTR on browse pages
- Detailed descriptions provide rich on-page content for indexing
- Meta description fallback chain: custom → description_standard → default

**No changes** from initial check - SEO enhancement validated in design

#### III. Performance & Scalability ✅

**Status**: STILL COMPLIANT

Design confirms no performance issues:
- Text columns are part of products table (no JOINs needed)
- Fallback methods use in-memory string truncation (data-model.md)
- Character counter is client-side JavaScript (contracts/README.md)
- Migration uses `find_each` for batch processing (research.md)

**No changes** from initial check - performance constraints met

#### IV. Security & Payment Integrity ✅

**Status**: STILL COMPLIANT

Design confirms security measures:
- Views use Rails auto-escaping (XSS protection)
- Admin form uses Rails form helpers (CSRF protection)
- `simple_format` helper sanitizes HTML in detailed descriptions
- CSV data is trusted source (not user input)

**No changes** from initial check - security best practices followed

#### V. Code Quality & Maintainability ✅

**Status**: STILL COMPLIANT

Design confirms maintainability:
- Migration fully reversible (down method in research.md)
- Clear method naming in data-model.md
- Single Responsibility maintained (models/views/controllers separation)
- Standard Rails patterns throughout (no custom abstractions)

**No changes** from initial check - code quality standards met

### Post-Design Overall: ✅ PASS

All five constitution principles remain satisfied after design phase. No new violations introduced. Design artifacts (research.md, data-model.md, contracts/, quickstart.md) align with constitution requirements.

---

## Planning Phase Complete

### Artifacts Generated

**Phase 0 (Research)**:
- ✅ `research.md` - Technical decisions and best practices

**Phase 1 (Design & Contracts)**:
- ✅ `data-model.md` - Database schema changes and entity model
- ✅ `contracts/README.md` - API contracts and interfaces
- ✅ `quickstart.md` - Implementation guide with TDD workflow
- ✅ Agent context updated (`CLAUDE.md`)

### Constitution Gates

- ✅ Pre-planning gate: PASSED
- ✅ Post-design gate: PASSED

### Ready for Next Phase

**Next Command**: `/speckit.tasks`

This will generate the detailed task breakdown (`tasks.md`) organized by user story with test tasks listed before implementation tasks following TDD workflow.

**Implementation**: After tasks.md is generated, use `/speckit.implement` to execute tasks with automated TDD enforcement.

### Summary

Planning complete for Product Descriptions Enhancement feature. All design artifacts created, constitution compliance verified twice (pre and post-design), and agent context updated. Implementation can proceed following the TDD workflow defined in quickstart.md and enforced by upcoming tasks.md.
