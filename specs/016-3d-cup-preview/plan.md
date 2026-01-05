# Implementation Plan: 3D Cup Preview

**Branch**: `016-3d-cup-preview` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/016-3d-cup-preview/spec.md`

## Summary

Add an interactive 3D preview to the branded product configurator that displays customers' uploaded designs wrapped onto a rotating cup in real-time. The feature uses WebGL-based 3D rendering with a purchased 3D model, integrating with the existing Stimulus-based configurator via event dispatch. PNG/JPG images trigger the 3D preview; PDF/AI files show a helpful message. Graceful fallback maintains static product photo for unsupported browsers.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x (backend), JavaScript ES2022 (frontend)
**Primary Dependencies**: Three.js ^0.170.0 (3D rendering), Stimulus ^3.2.2 (existing), Vite 6.x (existing bundler)
**Storage**: Static GLB model file in `public/models/`, client-side texture processing (no server storage)
**Testing**: Rails system tests (Capybara + Selenium), manual browser testing for WebGL
**Target Platform**: Web browsers (Chrome, Firefox, Safari, Edge - desktop and mobile)
**Project Type**: Web application (Rails backend, Vite/Stimulus frontend)
**Performance Goals**: 3D preview visible within 3 seconds of upload, 30+ fps rendering, <200KB lazy-loaded bundle
**Constraints**: WebGL required (graceful fallback for ~1% unsupported browsers), client-side only processing
**Scale/Scope**: Single product type initially (8oz hot cups), ~600x600px preview container

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Test-First Development** | PASS | System tests for 3D preview flow; fixtures for product data |
| **II. SEO & Structured Data** | N/A | No new public pages; client-side enhancement only |
| **III. Performance & Scalability** | PASS | Lazy-loaded Three.js (~150KB gzipped), pause rendering when hidden |
| **IV. Security & Payment Integrity** | PASS | No user data transmitted; client-side image processing only |
| **V. Code Quality & Maintainability** | PASS | Stimulus controller pattern, separate lib for 3D logic |
| **Technology Constraints** | PASS | Uses Hotwire/Stimulus patterns (not React); Vite for bundling |

**Gate Result**: PASS - All applicable principles satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/016-3d-cup-preview/
├── plan.md              # This file
├── research.md          # Phase 0 output - Three.js best practices
├── data-model.md        # Phase 1 output - No database changes
├── quickstart.md        # Phase 1 output - Development setup
├── contracts/           # Phase 1 output - Controller events API
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
├── frontend/
│   └── javascript/
│       ├── controllers/
│       │   ├── branded_configurator_controller.js  # MODIFY: Add event dispatch
│       │   └── cup_preview_controller.js           # NEW: Stimulus controller
│       └── lib/
│           └── cup_preview.js                      # NEW: Three.js scene logic
└── views/
    └── branded_products/
        └── _branded_configurator.html.erb          # MODIFY: Add canvas element

public/
└── models/
    └── hot_cup_8oz.glb                             # NEW: 3D cup model (purchased)

test/
└── system/
    └── cup_preview_test.rb                         # NEW: System tests
```

**Structure Decision**: Follows existing Rails + Stimulus architecture. New `lib/` directory for shared JavaScript modules (Three.js logic). Stimulus controller for DOM integration. Static 3D model in `public/` for direct browser access.

## Complexity Tracking

> No constitution violations - no justifications needed.
