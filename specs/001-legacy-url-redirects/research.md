# Research: Legacy URL Smart Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-14
**Status**: Complete

## Overview

This document captures technical decisions and research findings for implementing the legacy URL redirect seeding and testing functionality.

## Technical Decisions

### Decision 1: CSV Parsing Strategy

**Chosen**: Use Ruby's built-in CSV library with manual parsing in seed file
**Rationale**:
- CSV library is stdlib (no additional dependencies)
- Simple, straightforward parsing for 64 rows
- Seed file is already written in Ruby
- Easy to add transformations or validations during import

**Alternatives Considered**:
- **ActiveRecord import gem**: Rejected - adds dependency for minimal benefit
- **Direct SQL INSERT**: Rejected - loses ActiveRecord validations and callbacks
- **JSON format**: Rejected - CSV already exists and is human-readable

**Implementation Notes**:
```ruby
require 'csv'

CSV.foreach(Rails.root.join('config/legacy_redirects.csv'), headers: true) do |row|
  # Parse source URL to extract legacy_path
  # Parse target URL to extract target_slug and variant_params
  # Create/update LegacyRedirect record
end
```

### Decision 2: URL Parsing for Variant Parameters

**Chosen**: Parse target URLs using URI library and CGI.parse for query strings
**Rationale**:
- Target URLs in CSV contain full paths like `/products/pizza-box?size=12in&colour=kraft`
- Need to extract slug (`pizza-box`) and variant params (`{size: "12in", colour: "kraft"}`)
- URI and CGI are stdlib, battle-tested, handle edge cases (encoding, special chars)

**Alternatives Considered**:
- **Regex matching**: Rejected - fragile, doesn't handle URL encoding properly
- **Manual string splitting**: Rejected - error-prone, missing edge case handling
- **Addressable gem**: Rejected - unnecessary dependency for simple URL parsing

**Implementation Notes**:
```ruby
uri = URI.parse(target_url)
target_slug = uri.path.sub('/products/', '')
variant_params = URI.decode_www_form(uri.query || '').to_h
```

### Decision 3: Idempotent Seeding

**Chosen**: Use `find_or_create_by!` with `legacy_path` as unique key
**Rationale**:
- Allows running seeds multiple times without duplicates
- Updates existing redirects if target or params change
- Fails loudly on validation errors (! version)
- Maintains referential integrity (existing hit counts preserved)

**Alternatives Considered**:
- **Truncate and recreate**: Rejected - loses hit_count analytics data
- **find_or_initialize_by + save**: Rejected - less atomic, more complex error handling
- **upsert_all**: Rejected - bypasses ActiveRecord validations

**Implementation Notes**:
```ruby
LegacyRedirect.find_or_create_by!(legacy_path: source_path) do |redirect|
  redirect.target_slug = target_slug
  redirect.variant_params = variant_params
  redirect.active = true
end
```

### Decision 4: Testing Strategy

**Chosen**: Use existing test suite + manual browser testing of sample redirects
**Rationale**:
- Test infrastructure already exists and comprehensive
- Seed data validation via model tests (target products exist)
- Integration tests verify redirect flow works end-to-end
- System tests simulate real browser requests
- Manual testing validates user experience for 5-10 sample URLs

**Test Coverage**:
1. **Model tests**: Validate seed data integrity (all target products exist)
2. **Middleware tests**: Verify request interception and 301 response
3. **Integration tests**: End-to-end redirect flow from legacy URL to product page
4. **System tests**: Browser-based testing with real HTTP requests
5. **Manual testing**: Verify variant pre-selection in product page UI

**Alternatives Considered**:
- **Automated testing of all 64 URLs**: Rejected - slow, diminishing returns
- **Skip manual testing**: Rejected - need to verify user-facing behavior
- **Load testing**: Out of scope - feature performance already validated

## Data Mapping Analysis

### CSV Structure

```csv
source,target
/product/14-360-x-360mm-pizza-box-kraft,/products/pizza-box?size=16in&colour=kraft
/product/12-310-x-310mm-pizza-box-kraft,/products/pizza-box?size=12in&colour=kraft
...
```

**Fields**:
- `source`: Legacy URL path (e.g., `/product/12-310-x-310mm-pizza-box-kraft`)
- `target`: New URL with query params (e.g., `/products/pizza-box?size=12in&colour=kraft`)

**Data Quality**:
- 64 total mappings (verified by line count)
- All sources start with `/product/` (consistent pattern)
- All targets start with `/products/` (valid Rails route)
- Query parameters use lowercase keys (`size`, `colour`)

### Variant Parameter Extraction

**Size Formats**:
- Dimensions: `12in`, `14in`, `360mm`, `500ml`, `750ml`
- Volume: `8oz`, `12oz`, `16oz`, `20oz`
- Paper sizes: `40x40cm`, `24x24cm`, `25x25cm`
- Special: `pint`, `2cup`, `8fold-3ply`, `12-20oz-compatible`

**Colour Formats**:
- Materials: `kraft`, `natural`, `natural-beige`
- Colors: `white`, `black`, `clear`

**Edge Cases**:
- Some targets have only `size` parameter (no colour)
- Some targets have only `colour` parameter (no size)
- Empty parameters stored as `{}` (empty hash)

## Product Slug Validation

**Requirement**: All `target_slug` values in CSV must reference existing products in database

**Validation Strategy**:
1. Model validation (`target_slug_exists`) prevents invalid slugs
2. Seed file will fail loudly if product doesn't exist
3. Pre-seed check: Query all unique slugs from CSV and verify against Product table

**Sample Validation Query**:
```ruby
csv_slugs = CSV.read('config/legacy_redirects.csv', headers: true)
  .map { |row| URI.parse(row['target']).path.sub('/products/', '') }
  .uniq

missing_slugs = csv_slugs - Product.pluck(:slug)
# Should be empty array []
```

## Performance Considerations

### Seed Performance
- 64 database inserts/updates (sequential)
- Each insert: 1 SELECT (find_or_create_by) + 1 INSERT or UPDATE
- Expected time: <5 seconds
- No optimization needed for this scale

### Runtime Performance (Already Optimized)
- Middleware adds single DB query per request matching `/product/*`
- Case-insensitive index on `legacy_path` ensures fast lookup
- Hit count increment is async-safe (atomic operation)
- No caching needed (DB query fast enough)

## Risk Assessment

### Low Risks
- **Duplicate mappings**: CSV has unique source paths (verified)
- **Invalid slugs**: Model validation + pre-seed check prevents
- **Performance**: Seed operation is one-time, runtime already optimized
- **Data loss**: Idempotent seeding preserves hit counts

### Medium Risks
- **Product deletion**: If product deleted after seed, redirects fail validation
  - Mitigation: Admin can mark redirect inactive instead of deleting
- **CSV format changes**: Manual CSV editing could break parsing
  - Mitigation: Add CSV schema validation before parsing

### Mitigated Risks
- **Concurrent requests during seed**: Seeds run in development/staging before production
- **Redirect loops**: Middleware only matches `/product/*`, new products use `/products/*`

## Next Steps

1. ✅ Update seed file to parse CSV and create redirects
2. ⏳ Run database migration (if not already run)
3. ⏳ Run seeds in development environment
4. ⏳ Verify tests pass
5. ⏳ Manual testing of sample redirects in browser
6. ⏳ Document findings and close planning phase
