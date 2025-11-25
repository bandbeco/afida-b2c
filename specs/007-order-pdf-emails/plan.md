# Implementation Plan: Order Summary PDF Attachment

**Branch**: `007-order-pdf-emails` | **Date**: 2025-11-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-order-pdf-emails/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Generate professional PDF order summaries and attach them to order confirmation emails. The PDF will include complete order details (line items, pricing, shipping address, VAT breakdown) with company branding (logo, colors, contact information). Admin users can preview PDFs from the order detail page. PDF generation must be performant (<3 seconds), produce small files (<500KB), and handle failures gracefully without blocking email delivery.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Prawn (~> 2.5), prawn-table (~> 0.2)
**Storage**: On-demand generation (no caching in Phase 1, Active Storage option for future)
**Testing**: Rails test framework (Minitest) with system tests for email attachments
**Target Platform**: Linux server (production), macOS (development)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: <3 seconds PDF generation for 20-item orders, <500KB file size for 95% of orders
**Constraints**: Must not block email delivery on PDF generation failure, must support logo image embedding, must render correctly on all platforms (Windows, Mac, Linux, iOS, Android)
**Scale/Scope**: Integrates with existing Order/OrderItem models and OrderMailer, adds preview endpoint in Admin::OrdersController

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Test-First Development (TDD) ✅
- **Status**: PASS
- **Plan**: Tests will be written FIRST before implementation
- **Test Strategy**:
  - Unit tests for PDF generation service (test PDF content, formatting, file size)
  - Integration tests for OrderMailer with attachment
  - System tests for admin preview functionality
  - Test failure scenarios (PDF generation errors, missing data)
- **Coverage**: Models, services, mailers, controllers (admin preview)

### Principle II: SEO & Structured Data ✅
- **Status**: PASS (Not Applicable)
- **Rationale**: This feature is backend-only (email/PDF generation), no public-facing pages affected. Existing product/category SEO unchanged.

### Principle III: Performance & Scalability ✅
- **Status**: PASS
- **Plan**:
  - PDF generation will use efficient rendering (avoid N+1 queries by eager loading order_items and products)
  - Async PDF generation considered if synchronous approach too slow
  - File size optimization through proper image compression (logo) and minimal inline styling
  - Background job for PDF generation if needed (Solid Queue integration)
- **Metrics**: <3 seconds for 20-item orders, <500KB file size

### Principle IV: Security & Payment Integrity ✅
- **Status**: PASS
- **Plan**:
  - No user input involved in PDF generation (all data from trusted Order model)
  - PDF content sanitized to prevent injection attacks
  - Admin preview requires authentication (existing admin auth)
  - No sensitive payment details in PDF (no CVV, full card numbers)
  - PDF generation errors logged but don't expose sensitive data

### Principle V: Code Quality & Maintainability ✅
- **Status**: PASS
- **Plan**:
  - Extract PDF generation logic into dedicated service class (`OrderPdfGenerator`)
  - Single Responsibility: Service handles PDF generation, Mailer handles email delivery
  - RuboCop compliance enforced
  - Clear error handling with fallback behavior
  - Database-agnostic approach (no schema changes required)

**Overall Status**: ✅ ALL GATES PASSED - Proceed to Phase 0 Research

---

## Constitution Re-Check (Post-Design)

*Re-evaluated after Phase 1 design completion*

### Principle I: Test-First Development (TDD) ✅
- **Status**: PASS
- **Implementation**: Quickstart guide includes full TDD workflow (RED-GREEN-REFACTOR)
- **Test files created**:
  - `test/services/order_pdf_generator_test.rb` (unit tests)
  - `test/mailers/order_mailer_test.rb` (integration tests)
  - `test/controllers/admin/orders_controller_test.rb` (controller tests)
- **Tests written BEFORE implementation**: Quickstart enforces RED phase first

### Principle II: SEO & Structured Data ✅
- **Status**: PASS (Not Applicable)
- **Confirmation**: No public-facing pages modified, backend-only feature

### Principle III: Performance & Scalability ✅
- **Status**: PASS
- **Design decisions**:
  - Eager loading enforced: `Order.includes(:order_items)` in controllers
  - On-demand generation (no database writes during email send)
  - File size optimization: Logo compression, minimal styling
  - Performance targets documented: <3s generation, <500KB file size
  - Future-proof: Clear path to async generation if needed (Solid Queue)

### Principle IV: Security & Payment Integrity ✅
- **Status**: PASS
- **Design verification**:
  - No user input in PDF generation (Order data only)
  - Admin preview requires authentication (existing admin auth)
  - Error handling doesn't expose sensitive data
  - No payment details in PDF (only order totals)
  - Prawn gem (pure Ruby) - no external binary security risks

### Principle V: Code Quality & Maintainability ✅
- **Status**: PASS
- **Design confirmation**:
  - Service class pattern: `OrderPdfGenerator` (Single Responsibility)
  - Clear separation: Service generates PDF, Mailer handles email, Controller handles preview
  - Error handling with graceful degradation
  - No schema changes (leverages existing models)
  - Code examples in quickstart follow Rails conventions
  - RuboCop compliance enforced in deployment checklist

**Overall Status**: ✅ ALL PRINCIPLES SATISFIED - Design phase complete

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
├── services/
│   └── order_pdf_generator.rb      # NEW: PDF generation service
├── mailers/
│   └── order_mailer.rb              # MODIFIED: Add PDF attachment
├── controllers/
│   └── admin/
│       └── orders_controller.rb     # MODIFIED: Add preview_pdf action
├── views/
│   └── admin/
│       └── orders/
│           └── show.html.erb        # MODIFIED: Add "Preview PDF" button
├── models/
│   └── order.rb                     # Existing (no changes needed)
└── frontend/
    └── images/
        └── logo.png                 # Existing (used in PDF)

test/
├── services/
│   └── order_pdf_generator_test.rb  # NEW: PDF generation tests
├── mailers/
│   └── order_mailer_test.rb         # MODIFIED: Test attachment
├── integration/
│   └── order_pdf_email_test.rb      # NEW: End-to-end test
└── system/
    └── admin/
        └── order_preview_test.rb    # NEW: Admin preview test
```

**Structure Decision**: Rails monolith structure with services pattern. PDF generation logic extracted into a dedicated service class (`OrderPdfGenerator`) following Single Responsibility Principle. The service will be called by both the mailer (for email attachments) and the admin controller (for preview). Tests follow Rails conventions with unit tests for the service, integration tests for mailer behavior, and system tests for admin preview UI.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - No constitution violations. All principles satisfied.
