---
type: Plan
description: Plan to replace the single combined variant dropdown on product pages with separate Size and Color dropdowns matched by JavaScript.
status: superseded
timestamp: 2025-10-23
superseded_by: /plans/2026-01-10-variant-pages-design.md
---

# Separate Option Selectors for Product Pages

## Goal
Replace single variant dropdown with separate dropdowns for Size, Color, and other options.

## Current
- One dropdown showing all variants: "8oz White", "8oz Black", "12oz White"...

## Desired
- Size dropdown: "8oz", "12oz", "16oz"
- Color dropdown: "White", "Black", "Kraft"
- JavaScript finds matching variant based on selections
- Updates price dynamically

## Implementation
1. Update ProductsController to pass @product_options
2. Create option selectors in view (one per assigned option)
3. Add Stimulus controller for variant matching
4. Update price/image when selections change

Similar to branded configurator but for standard products.

Estimated: 2-3 hours
