# Implementation Plan: Homepage Branding Section Redesign

**Branch**: `013-homepage-branding` | **Date**: 2025-12-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/013-homepage-branding/spec.md`

## Summary

Redesign the homepage branding section (`_branding.html.erb` partial) to feature a full-width masonry photo collage showcasing real customer-branded products, followed by a compelling headline ("Your Brand. Your Cup."), trust badges with concrete numbers (UK, 1,000 min, 20 days, £0), and a primary CTA button. The design draws from the dedicated branding page to create a "mini landing page" experience within the homepage.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Vite Rails, TailwindCSS 4, DaisyUI, Hotwire (Turbo + Stimulus)
**Storage**: N/A (no data changes - view-only feature)
**Testing**: Rails system tests (Capybara + Selenium)
**Target Platform**: Web (responsive: mobile, tablet, desktop)
**Project Type**: Web application (Rails monolith)
**Performance Goals**: Page load under 3 seconds, no layout shift during image loading
**Constraints**: Must use existing branding gallery images, maintain neobrutalist design language
**Scale/Scope**: Single partial file modification, responsive across 4 breakpoints

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | System tests will verify collage rendering, CTA functionality, responsive behavior |
| II. SEO & Structured Data | ✅ PASS | No SEO changes required (homepage SEO already implemented), images will have alt text |
| III. Performance & Scalability | ✅ PASS | Images already optimized (WebP), no database queries, CSS-only masonry layout |
| IV. Security & Payment Integrity | ✅ N/A | No user input, authentication, or payment handling |
| V. Code Quality & Maintainability | ✅ PASS | RuboCop will validate ERB/Ruby, clean TailwindCSS utilities, no complex logic |

**Gate Result**: PASS - All applicable principles satisfied. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/013-homepage-branding/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
├── views/
│   └── pages/
│       └── partials/
│           └── _branding.html.erb    # Primary file to modify
├── frontend/
│   ├── entrypoints/
│   │   └── application.css           # May need masonry CSS if not pure Tailwind
│   └── images/
│       └── branding/                 # Existing customer photos (6 images)
│           ├── DSC_6621.webp
│           ├── DSC_6736.webp
│           ├── DSC_6770.webp
│           ├── DSC_6872.webp
│           ├── DSC_7193.webp
│           └── DSC_7239.webp

test/
└── system/
    └── homepage_branding_test.rb     # New system test file
```

**Structure Decision**: Single partial modification within existing Rails view structure. No new directories or architectural changes required.

## Complexity Tracking

> No violations to justify - all Constitution principles satisfied.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | - | - |
