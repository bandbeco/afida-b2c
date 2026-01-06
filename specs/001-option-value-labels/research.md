# Research: Product Option Value Labels

**Feature**: 001-option-value-labels
**Date**: 2026-01-06

## Research Questions Addressed

### 1. JSONB vs Join Table for Variant Options

**Decision**: Replace JSONB with join table (`variant_option_values`)

**Rationale**:
- JSONB provides flexibility when option types are unknown or highly variable
- This codebase has ~3 stable option types (size, colour, material/type)
- Labels require a relationship to `ProductOptionValue.label` - JSONB isolates data from other tables
- Join table enables referential integrity (no invalid option values)
- Join table enables efficient querying ("all 8oz variants" via SQL joins)

**Alternatives Considered**:
1. **Keep JSONB, add lookup layer** - Minimal change but doesn't solve tight coupling; every display point needs discipline to use helpers
2. **JSONB with IDs instead of values** - Loses human-readability of JSONB while keeping denormalization
3. **Join table (chosen)** - Most normalized, cleanest separation, requires schema change but pre-launch allows re-seed

### 2. One-Value-Per-Option Constraint Enforcement

**Decision**: Database-level unique index with denormalized `product_option_id`

**Rationale**:
- Admins will edit variants in future (not just seeds)
- Database constraints are bulletproof; model validations can be bypassed with raw SQL
- Denormalization is minor (one extra FK column) and enables efficient constraint

**Alternatives Considered**:
1. **Model validation only** - Simpler schema but bypassable; risky when admins edit directly
2. **Database constraint (chosen)** - Requires denormalized `product_option_id` but guarantees integrity

### 3. Backwards Compatibility with Variant Selector

**Decision**: Maintain identical JSON structure via `option_values_hash` method

**Rationale**:
- Variant selector JS receives `{ option_values: { size: "8oz", colour: "White" } }`
- Sparse matrix filtering logic is frontend-side - only needs variant-to-options mapping
- New method `option_values_hash` returns same structure from join table
- Zero frontend changes required

**Alternatives Considered**:
1. **Change frontend to use new structure** - Unnecessary work; current structure is fine
2. **Backwards-compatible method (chosen)** - Model method abstracts data source change

### 4. Label Fallback Behavior

**Decision**: Fall back to `value` when `label` is blank or nil

**Rationale**:
- Some values are self-explanatory (e.g., "8-12oz", "White")
- Not all option values need custom labels
- Fallback enables gradual label addition without breaking display

**Implementation**:
```ruby
def option_labels_hash
  variant_option_values.includes(product_option_value: :product_option)
    .each_with_object({}) do |vov, hash|
      pov = vov.product_option_value
      hash[vov.product_option.name] = pov.label.presence || pov.value
    end
end
```

### 5. Migration Strategy

**Decision**: Re-seed approach (no data migration scripts)

**Rationale**:
- Site is pre-launch with no production data
- Re-seeding is simpler and less error-prone than data transformation
- Allows clean schema change without backwards-compatibility hacks

**Steps**:
1. Create `variant_option_values` table
2. Remove `option_values` JSONB column
3. Update seed files to use join table
4. `rails db:reset` to drop and re-seed

### 6. Performance Considerations

**Decision**: Use `includes()` for eager loading throughout

**Rationale**:
- Variant options are accessed frequently (product pages, cart, orders)
- Eager loading prevents N+1 queries
- Join table allows efficient SQL queries for option-based filtering

**Key Patterns**:
```ruby
# Eager load option values with their options
active_variants.includes(option_values: :product_option)

# Efficient query for variants with specific option
ProductVariant.joins(:option_values).where(product_option_values: { value: "8oz" })
```

## Files Analyzed

- `app/models/product_option.rb` - Existing option type model (unchanged)
- `app/models/product_option_value.rb` - Existing option value model with `value` and `label` columns (unchanged)
- `app/models/product_variant.rb` - Currently stores `option_values` as JSONB
- `app/models/product.rb` - Has `extract_options_from_variants` method to replace
- `app/helpers/products_helper.rb` - Has `option_value_label` helper to remove
- `db/seeds/products_from_csv.rb` - Current seeding approach builds JSONB directly
- `db/seeds/product_options.rb` - Seeds ProductOption and ProductOptionValue with labels

## Dependencies Identified

- `ProductOption` and `ProductOptionValue` tables must be seeded before `variant_option_values`
- Views displaying option values must be updated after model changes
- Seed file must be updated before `db:reset`

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Views missed during update | Display breaks | Grep for `option_values` usage; system test coverage |
| Seed data has invalid option values | Seed fails | `find_by!` raises error immediately; fix in seed data |
| N+1 queries introduced | Performance regression | Use `includes()` consistently; verify with Bullet gem |
| Variant selector breaks | Customer can't purchase | System test verifies identical behavior |
