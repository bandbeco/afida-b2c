# Research: Product Descriptions Enhancement

**Feature**: 004-product-descriptions
**Date**: 2025-11-15

## Overview

This feature enhances the product model with three description fields to support contextual content display across different page types. All technical decisions are straightforward Rails patterns with no unknowns requiring research.

## Technical Decisions

### 1. Database Column Types

**Decision**: Use `text` type for all three description fields (description_short, description_standard, description_detailed)

**Rationale**:
- PostgreSQL `text` type has no length limit (vs `string` limited to 255 chars)
- Descriptions vary significantly in length (short ~20 words, detailed ~150 words)
- Text fields support full-text search if needed in future
- No performance penalty in PostgreSQL (text and varchar are equivalent internally)

**Alternatives Considered**:
- `string` (varchar) - Rejected: 255 character limit insufficient for standard/detailed descriptions
- Separate `varchar` lengths per field - Rejected: Adds complexity, no benefit in PostgreSQL

### 2. Migration Strategy

**Decision**: Replace existing `description` column with three new columns in a single migration, populate from CSV data

**Rationale**:
- All product data in CSV is authoritative (per spec assumptions)
- Single migration is atomic and reversible
- `update_columns` for batch updates avoids callbacks and validations overhead
- CSV parsing with Ruby's CSV library is reliable and standard

**Alternatives Considered**:
- Keep old field temporarily - Rejected: Adds complexity, spec requires full replacement
- Manual SQL for migration - Rejected: ActiveRecord methods sufficient and more maintainable

### 3. Fallback Logic Pattern

**Decision**: Add helper methods to Product model that truncate longer descriptions when shorter ones missing

**Rationale**:
- Rails convention: business logic belongs in models
- Keeps views clean (no complex conditional logic)
- Reusable across all view contexts
- Testable in isolation

**Alternatives Considered**:
- View helpers - Rejected: Less reusable, harder to test
- Decorator pattern - Rejected: Overkill for simple truncation logic

### 4. Character Counter Implementation

**Decision**: Stimulus controller with `input` event listener for real-time counting

**Rationale**:
- Stimulus is project standard (already used for carousel, cart drawer)
- No server roundtrips needed (pure client-side)
- Automatic cleanup on disconnect
- DaisyUI provides color classes for visual feedback

**Alternatives Considered**:
- Vanilla JavaScript - Rejected: Stimulus provides lifecycle management and conventions
- Turbo Frames - Rejected: Unnecessary server involvement for character counting

### 5. SEO Meta Description Source

**Decision**: Use `description_standard` for SEO meta descriptions when custom `meta_description` is blank

**Rationale**:
- Standard description is ~30-40 words (ideal for meta descriptions: 150-160 chars)
- Already displayed above the fold on product pages (content parity)
- Existing SEO helper pattern supports this (just swap data source)

**Alternatives Considered**:
- Use `description_short` - Rejected: Too brief for informative meta descriptions
- Use `description_detailed` - Rejected: Too long, would need truncation

## Best Practices Applied

### Rails Migration Best Practices
- Reversible migrations with explicit `up` and `down` methods
- Batch updates using `find_each` to avoid memory issues
- Use `update_columns` to skip callbacks during migration
- CSV data validation (check for file existence, blank SKUs)

### ActiveRecord Patterns
- Keep model focused on data and business logic
- Helper methods named descriptively (`description_with_fallback`)
- No default scope changes (maintain existing behavior)

### Stimulus Controller Patterns
- Use data attributes for configuration (`data-character-counter-target`, `data-character-counter-max-value`)
- Target-based DOM selection (not querySelector)
- Value-based configuration for thresholds
- Class-based visual feedback using Tailwind/DaisyUI

### Test Coverage Strategy
- Model tests: Test fallback logic with various empty/present combinations
- Controller tests: Test form submission saves all three fields
- System tests: Test visual display on all four page types
- Helper tests: Test SEO meta description generation

## Dependencies

**No new dependencies** - All required tools already in stack:
- Ruby CSV library (stdlib)
- Stimulus (existing)
- TailwindCSS 4 / DaisyUI (existing)
- Minitest (existing)
- Capybara + Selenium (existing)

## Performance Considerations

**No performance concerns**:
- Text columns added to existing table (no JOIN overhead)
- Fallback logic is in-memory Ruby string truncation (negligible cost)
- Character counter runs in browser (zero server load)
- CSV migration runs once during deployment (not performance-critical)

## Security Considerations

**XSS Protection**:
- Rails auto-escapes ERB output by default
- Use `simple_format` helper for line breaks (sanitizes HTML)
- Admin form uses Rails form helpers (CSRF protection built-in)
- CSV data trusted (not user input)

## Conclusion

All technical decisions follow established Rails patterns and project conventions. No custom libraries or complex patterns needed. Implementation is straightforward CRUD enhancement with proper testing and migration practices.
