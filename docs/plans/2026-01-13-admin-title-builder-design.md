# Admin Product Title Builder Design

## Overview

Add a "Title Builder" section to the admin product edit form that exposes all fields used in `Product#generated_title` with a live preview.

## Problem

The admin product form only exposes the `name` field, but `generated_title` combines four fields: size, colour, material, and name. Admins have no visibility into how these fields affect the customer-facing title.

## Solution

A new "Title Builder" fieldset at the top of the form with:

- Four input fields: size, colour, material, name
- Live preview showing the generated title as you type
- Placeholder hints on empty fields

## Design Details

### Title Builder Section

Position: Top of form, before Status section.

**Fields (2x2 grid):**

| Field    | Type       | Required | Placeholder              |
|----------|------------|----------|--------------------------|
| Size     | text input | No       | "e.g. 12oz, 200mm, A4"   |
| Colour   | text input | No       | "e.g. White, Kraft, Black" |
| Material | text input | No       | "e.g. Paper, Bamboo, PLA" |
| Name     | text input | Yes      | "e.g. Single Wall Cup, Straws" |

**Preview:**

A styled box below the fields showing the generated title in real-time:

```
┌─────────────────────────────────────────────────┐
│  Generated Title                                │
│  12oz White Paper Single Wall Cup               │
└─────────────────────────────────────────────────┘
```

If all fields are empty, shows: "Enter product details above"

### Stimulus Controller

New `title_preview_controller.js`:

- Targets: size, colour, material, name inputs + preview output
- Triggers on `input` event from any field
- Logic mirrors Ruby: concatenate non-empty values, deduplicate case-insensitively
- ~20 lines, no API calls or debouncing needed

### Form Changes

1. Move `name` field from Details section to Title Builder
2. Add `size`, `colour`, `material` fields (exist in DB, not exposed)
3. Wire up Stimulus controller with data attributes
4. Style preview with `bg-base-200` bordered div

## Files to Modify

| File | Change |
|------|--------|
| `app/frontend/javascript/controllers/title_preview_controller.js` | Create new controller |
| `app/frontend/entrypoints/application.js` | Register controller in lazyControllers |
| `app/views/admin/products/_form.html.erb` | Add Title Builder section |

## Out of Scope

- No backend changes (fields exist, params permitted)
- No validation changes
- No changes to `generated_title` method
