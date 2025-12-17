<!--
Sync Impact Report
==================
Version Change: 1.0.0 → 1.1.0
Rationale: Added mandatory fixtures requirement to Test-First Development principle

Principles Updated:
- Test-First Development (TDD): Added "Fixtures MUST Be Used" subsection
  - Tests MUST use fixtures instead of inline Model.create!
  - Reference fixtures using accessor methods
  - NEVER delete fixtures with delete_all
  - Only use create! when testing creation-specific behavior

Templates Status:
✅ plan-template.md - Constitution Check section aligns with principles
✅ spec-template.md - User story and requirements structure supports TDD workflow
✅ tasks-template.md - Test-first task ordering enforced
✅ No agent-specific references found (generic guidance maintained)

Follow-up TODOs:
- None - principle addition is backward compatible
-->

# Afida E-Commerce Shop Constitution

## Core Principles

### I. Test-First Development (NON-NEGOTIABLE)

All features MUST follow strict Test-Driven Development (TDD):
- Tests written FIRST before any implementation code
- Tests MUST fail initially (red phase)
- Implementation proceeds only after failing tests exist
- Red-Green-Refactor cycle strictly enforced
- Test coverage tracked for models, controllers, services, and integrations
- System tests required for critical user flows (checkout, authentication, cart)

**Fixtures MUST Be Used (NON-NEGOTIABLE)**:
- Tests MUST use fixtures (`test/fixtures/*.yml`) instead of creating records inline with `Model.create!`
- Reference fixtures using accessor methods: `users(:one)`, `products(:widget)`, `reorder_schedules(:active_monthly)`
- If a test needs specific data not in fixtures, ADD it to the fixture file
- NEVER delete fixtures with `delete_all` to avoid test pollution—modify fixture data in setup instead
- Only use `Model.create!` when testing creation-specific behavior (e.g., validations, callbacks)

**Rationale**: TDD ensures code correctness, prevents regressions, and serves as living documentation. For an e-commerce platform handling payments and customer data, test coverage is non-negotiable for reliability and trust. Fixtures provide consistent, fast, and predictable test data that is shared across the test suite and easier to maintain than inline record creation.

### II. SEO & Structured Data

Every public-facing page MUST implement comprehensive SEO:
- Canonical URLs on all pages
- Meta tags (title, description) with database-driven customization
- Schema.org structured data (Product, Organization, Breadcrumb, CollectionPage)
- XML sitemap including all categories, products, and static pages
- Robots.txt with proper allow/disallow rules
- Open Graph and Twitter Card tags for social sharing

**Rationale**: E-commerce success depends on discoverability. Structured data improves search rankings, click-through rates, and social media presentation. SEO is not optional—it's core to business viability.

### III. Performance & Scalability

Application MUST maintain production-grade performance:
- Database queries MUST use eager loading to prevent N+1 queries
- Cart and product aggregations MUST use SQL-based calculations
- Memoization employed for frequently accessed computed values
- Asset compilation optimized with Vite for fast page loads
- Hotwire Turbo enabled for SPA-like navigation without full page reloads
- Background jobs (Solid Queue) for async operations (emails, reports)
- Caching strategy (Solid Cache) for expensive computations

**Rationale**: Poor performance directly impacts conversion rates. Studies show 1-second delay reduces conversions by 7%. Performance optimization is a competitive advantage and user experience requirement.

### IV. Security & Payment Integrity

Security MUST be built into every layer:
- No command injection, XSS, SQL injection, or OWASP Top 10 vulnerabilities
- Stripe Checkout integration MUST validate session IDs and prevent duplicate orders
- Admin area MUST have authentication before production deployment
- Credentials MUST use Rails encrypted credentials (never committed to version control)
- HTTPS/SSL required in production
- Brakeman security scanner MUST pass before deployment
- Input validation and sanitization on all user-provided data
- CSRF protection enabled on all state-changing operations

**Rationale**: E-commerce platforms are high-value targets. Security breaches destroy customer trust, result in financial liability, and can shut down businesses. Security is a foundation, not a feature.

### V. Code Quality & Maintainability

Code MUST maintain high standards for long-term maintainability:
- RuboCop linter (rails-omakase config) MUST pass before commits
- No default scopes except where explicitly documented (e.g., `Product` active filter)
- Explicit scopes preferred over implicit behavior
- Single Responsibility Principle applied to models, services, controllers
- DRY principle balanced with readability (avoid premature abstraction)
- Database migrations MUST be reversible
- Clear naming conventions (slugs for SEO-friendly URLs, descriptive method names)
- Comments required only for complex business logic (code should be self-documenting)

**Rationale**: Technical debt compounds over time. Maintaining quality standards from day one prevents future rewrites, reduces bug density, and enables faster feature development as the codebase grows.

## Technology Standards

### Required Stack Components

**Backend Framework**: Rails 8.x
- PostgreSQL 14+ as primary database
- Solid Queue for background jobs
- Solid Cache for application caching
- Solid Cable for Action Cable
- Ruby 3.3.0+

**Frontend Framework**: Vite + Hotwire
- Vite Rails for asset bundling
- TailwindCSS 4 for styling
- DaisyUI for component library
- Hotwire (Turbo + Stimulus) for interactivity
- Node.js 18+

**Payment Processing**: Stripe Checkout
- Stripe API for payment sessions
- Webhook integration for payment confirmation
- Test mode enforced in development/staging

**Email**: Mailgun
- Transactional emails (order confirmations, password resets)
- Production credentials required

**Storage**: Active Storage
- Local storage in development
- AWS S3 in production

### Technology Constraints

- NO client-side state management frameworks (React state, Redux, etc.) - use Hotwire patterns
- NO GraphQL - REST API patterns with Rails conventions
- NO complex frontend build tools beyond Vite
- NO ORMs other than ActiveRecord
- NO NoSQL databases for primary data storage
- Backend rendering preferred over client-side rendering for SEO and performance

**Rationale**: Rails conventions reduce complexity and leverage battle-tested patterns. Hotwire provides modern UX without JavaScript framework complexity. Constraints prevent analysis paralysis and technical fragmentation.

## Development Workflow

### Feature Development Lifecycle

1. **Specification** (via `/speckit.specify`):
   - User stories with acceptance criteria
   - Functional requirements enumerated
   - Success criteria defined and measurable

2. **Planning** (via `/speckit.plan`):
   - Technical approach documented
   - Database schema changes identified
   - API contracts defined (if applicable)
   - Constitution check performed

3. **Task Breakdown** (via `/speckit.tasks`):
   - Tasks organized by user story
   - Test tasks listed BEFORE implementation tasks
   - Dependencies and parallel opportunities identified

4. **Implementation** (via `/speckit.implement` or manual):
   - Write failing tests FIRST
   - Implement minimum code to pass tests
   - Refactor for quality
   - Verify all tests pass
   - Run linters (RuboCop) and security scanners (Brakeman)

5. **Review & Deployment**:
   - Code review against plan and constitution
   - SEO validation (`rails seo:validate`)
   - Performance verification (N+1 query check with Bullet gem)
   - Deployment checklist followed

### Quality Gates

**Pre-Commit**:
- All tests passing
- RuboCop linter passing
- No security warnings from Brakeman

**Pre-Deployment**:
- Test coverage maintained or improved
- SEO validation passing
- Performance benchmarks met
- Admin authentication enabled (production only)
- SSL/HTTPS configured
- Production credentials configured
- Database migrations tested
- Asset precompilation successful

**Rationale**: Quality gates prevent defects from reaching production and enforce discipline at critical checkpoints. Automation reduces human error and review burden.

## Governance

### Amendment Process

1. **Proposal**: Document proposed change with justification
2. **Review**: Assess impact on existing principles and templates
3. **Approval**: Technical lead or team consensus required
4. **Migration**: Update constitution, increment version, sync templates
5. **Communication**: Notify team and update dependent documentation

### Versioning Policy

Constitution follows semantic versioning:
- **MAJOR** (X.0.0): Backward-incompatible changes (principle removal/redefinition)
- **MINOR** (x.Y.0): New principles added or existing principles materially expanded
- **PATCH** (x.y.Z): Clarifications, wording improvements, non-semantic refinements

### Compliance Review

- All PRs and code reviews MUST verify compliance with constitution principles
- Violations require explicit justification documented in plan.md Complexity Tracking section
- Use `CLAUDE.md` for agent-specific runtime development guidance
- Constitution supersedes all other practices unless explicitly amended

### Enforcement

- Constitution principles are NON-NEGOTIABLE unless amended
- Complexity and deviation from principles MUST be justified before approval
- Technical debt introduced by violating principles MUST be tracked and scheduled for remediation

**Version**: 1.1.0 | **Ratified**: 2025-01-13 | **Last Amended**: 2025-12-17
