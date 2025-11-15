# Quickstart: Product Descriptions Enhancement

**Feature**: 004-product-descriptions
**Branch**: `004-product-descriptions`
**Estimated Time**: 4-6 hours (including TDD)

## Prerequisites

- Ruby 3.3.0+
- Rails 8.x environment set up
- PostgreSQL 14+ running
- Vite dev server configured
- Access to `lib/data/products.csv`

## Quick Start (5 minutes)

### 1. Checkout Feature Branch

```bash
git checkout 004-product-descriptions
```

### 2. Verify CSV Data Source

```bash
head -n 5 lib/data/products.csv
# Should show: product,category,slug,description_short,description_standard,description_detailed,...
```

### 3. Review Planning Documents

```bash
# Feature specification
cat specs/004-product-descriptions/spec.md

# Implementation plan
cat specs/004-product-descriptions/plan.md

# Data model
cat specs/004-product-descriptions/data-model.md
```

## Implementation Sequence (TDD)

### Phase 1: Database Migration (30 min)

**Goal**: Create reversible migration that replaces `description` with three new fields

```bash
# Generate migration (already done)
# rails generate migration ReplaceProductDescriptionWithThreeFields

# Edit migration file
# db/migrate/TIMESTAMP_replace_product_description_with_three_fields.rb

# Write migration test FIRST
# test/db/migrate/replace_product_description_with_three_fields_test.rb

# Run test (should FAIL - red phase)
rails test test/db/migrate/

# Implement migration
# - Add three columns
# - Populate from CSV
# - Remove old column

# Run test (should PASS - green phase)
rails test test/db/migrate/

# Run migration
rails db:migrate

# Verify schema
rails db:migrate:status
cat db/schema.rb | grep description
```

**Validation**:
- [ ] Migration adds three new columns
- [ ] Migration removes old description column
- [ ] Migration populates data from CSV
- [ ] Down migration is reversible
- [ ] All tests pass

### Phase 2: Model Methods with Fallback Logic (45 min)

**Goal**: Add helper methods to Product model for graceful fallback

```bash
# Write model tests FIRST (red phase)
# test/models/product_test.rb
#   - Test description_short_with_fallback (all combinations)
#   - Test description_standard_with_fallback
#   - Test truncate_to_words private method

rails test test/models/product_test.rb
# Should FAIL

# Implement model methods
# app/models/product.rb
#   - description_short_with_fallback
#   - description_standard_with_fallback
#   - description_detailed_with_fallback
#   - truncate_to_words (private)

rails test test/models/product_test.rb
# Should PASS
```

**Validation**:
- [ ] Fallback methods return correct values
- [ ] Truncation works (15 words for short, 35 for standard)
- [ ] All edge cases handled (all blank, various combinations)
- [ ] All model tests pass

### Phase 3: Shop & Category Page Views (1 hour)

**Goal**: Display short descriptions on product cards

```bash
# Write system tests FIRST (red phase)
# test/system/shop_descriptions_test.rb
# test/system/category_descriptions_test.rb

rails test:system
# Should FAIL

# Update views
# app/views/pages/shop.html.erb - Add description_short_with_fallback
# app/views/categories/show.html.erb - Add description_short_with_fallback

rails test:system
# Should PASS

# Manual verification
bin/dev
# Visit http://localhost:3000/shop
# Visit http://localhost:3000/categories/cups-and-lids
```

**Validation**:
- [ ] Short descriptions appear on shop page cards
- [ ] Short descriptions appear on category page cards
- [ ] Fallback logic works for products with missing short descriptions
- [ ] Styling looks good (text-sm, gray-600)
- [ ] System tests pass

### Phase 4: Product Detail Page Views (1 hour)

**Goal**: Display standard (intro) and detailed (main content) descriptions

```bash
# Write system tests FIRST (red phase)
# test/system/product_descriptions_test.rb

rails test:system
# Should FAIL

# Update view
# app/views/products/show.html.erb
#   - Add description_standard_with_fallback above fold
#   - Add description_detailed_with_fallback below fold

rails test:system
# Should PASS

# Manual verification
bin/dev
# Visit http://localhost:3000/products/compostable-paper-cups-ukca-marked
```

**Validation**:
- [ ] Standard description appears above fold
- [ ] Detailed description appears below fold
- [ ] Content flows naturally (continuous scroll, no tabs)
- [ ] simple_format helper preserves line breaks
- [ ] System tests pass

### Phase 5: SEO Helper Update (30 min)

**Goal**: Use description_standard for meta descriptions

```bash
# Write helper tests FIRST (red phase)
# test/helpers/seo_helper_test.rb

rails test test/helpers/seo_helper_test.rb
# Should FAIL

# Update helper
# app/helpers/seo_helper.rb
#   - Add fallback chain: custom meta_description → description_standard → default

rails test test/helpers/seo_helper_test.rb
# Should PASS

# Manual verification
bin/dev
# Visit any product page
# View page source, check <meta name="description"> tag
```

**Validation**:
- [ ] Meta description uses description_standard when custom blank
- [ ] Meta description uses custom meta_description when present
- [ ] Fallback chain works correctly
- [ ] Helper tests pass

### Phase 6: Admin Form with Character Counters (2 hours)

**Goal**: Add three description fields to admin form with real-time character counting

```bash
# Write Stimulus controller tests FIRST (if using Stimulus test helpers)
# OR rely on system tests for integration testing

# Write system tests FIRST (red phase)
# test/system/admin_product_descriptions_test.rb

rails test:system
# Should FAIL

# Create Stimulus controller
# app/frontend/javascript/controllers/character_counter_controller.js

# Update admin form view
# app/views/admin/products/_form.html.erb
#   - Add three textarea fields
#   - Attach character-counter Stimulus controller
#   - Add counter display elements

# Update strong parameters
# app/controllers/admin/products_controller.rb
#   - Add :description_short, :description_standard, :description_detailed to permit

# Register Stimulus controller (if not auto-registered)
# app/frontend/entrypoints/application.js

rails test:system
# Should PASS

# Manual verification
bin/dev
# Visit http://localhost:3000/admin/products/1/edit
# Type in description fields
# Verify character count updates in real-time
# Verify color coding (green/yellow/red)
# Save and verify data persists
```

**Validation**:
- [ ] Three description fields visible in admin form
- [ ] Character counters update in real-time
- [ ] Color coding works (green in range, yellow too few, red too many)
- [ ] Form submission saves all three fields
- [ ] Blank fields allowed (optional)
- [ ] System tests pass

### Phase 7: Integration Testing & Verification (30 min)

**Goal**: Run full test suite and verify all features working

```bash
# Run full test suite
rails test
rails test:system

# Check coverage (if using SimpleCov)
open coverage/index.html

# Manual end-to-end verification
bin/dev

# Test flow:
# 1. Visit shop page → verify short descriptions on cards
# 2. Click a product → verify standard intro + detailed content
# 3. Visit admin → edit product → verify character counters work
# 4. Save changes → verify data persists
# 5. View product page source → verify meta description uses description_standard

# Run linters
rubocop
# Fix any issues

# Run security scanner
brakeman
# Should have no new warnings
```

**Validation**:
- [ ] All tests pass (models, controllers, system, helpers)
- [ ] RuboCop passes
- [ ] Brakeman passes
- [ ] Manual testing confirms all features working
- [ ] No regressions in existing functionality

## Common Issues & Troubleshooting

### Issue: Migration fails with "column description does not exist"

**Cause**: Migration already ran or schema out of sync

**Solution**:
```bash
rails db:rollback
rails db:migrate
```

### Issue: CSV data not populating

**Cause**: CSV file path wrong or SKUs don't match

**Solution**:
```bash
# Verify CSV path
ls -la lib/data/products.csv

# Check SKU matching
rails console
Product.pluck(:sku)
# Compare with CSV SKUs
```

### Issue: Character counter not working

**Cause**: Stimulus controller not registered or data attributes wrong

**Solution**:
```bash
# Verify Stimulus registration
grep character_counter app/frontend/entrypoints/application.js

# Check browser console for errors
# Visit admin page with browser dev tools open
```

### Issue: Descriptions not showing on pages

**Cause**: View not updated or method name wrong

**Solution**:
```bash
# Verify helper method name
grep description_short_with_fallback app/views/pages/shop.html.erb

# Check nil values in console
rails console
Product.first.description_short_with_fallback
```

## Deployment Checklist

- [ ] All tests passing
- [ ] RuboCop passing
- [ ] Brakeman passing
- [ ] Migration tested locally
- [ ] Rollback tested locally
- [ ] CSV data verified complete
- [ ] Manual testing completed
- [ ] Git commit with descriptive message
- [ ] Push to remote branch
- [ ] Create pull request
- [ ] Code review completed
- [ ] Merge to main
- [ ] Deploy to staging
- [ ] Verify migration on staging
- [ ] Deploy to production
- [ ] Verify data populated on production

## Quick Reference

### File Locations

**Migration**: `db/migrate/TIMESTAMP_replace_product_description_with_three_fields.rb`
**Model**: `app/models/product.rb`
**Views**:
- `app/views/pages/shop.html.erb`
- `app/views/categories/show.html.erb`
- `app/views/products/show.html.erb`
- `app/views/admin/products/_form.html.erb`

**Stimulus**: `app/frontend/javascript/controllers/character_counter_controller.js`
**Helper**: `app/helpers/seo_helper.rb`
**CSV Data**: `lib/data/products.csv`

### Test Locations

**Models**: `test/models/product_test.rb`
**Migrations**: `test/db/migrate/replace_product_description_with_three_fields_test.rb`
**System Tests**:
- `test/system/shop_descriptions_test.rb`
- `test/system/category_descriptions_test.rb`
- `test/system/product_descriptions_test.rb`
- `test/system/admin_product_descriptions_test.rb`

**Helpers**: `test/helpers/seo_helper_test.rb`

### Commands

```bash
# Run specific test file
rails test test/models/product_test.rb

# Run system tests
rails test:system

# Run linter
rubocop

# Run security scanner
brakeman

# Start dev environment
bin/dev

# Database operations
rails db:migrate
rails db:rollback
rails db:migrate:status

# Console
rails console
```

## Next Steps

After this feature is complete:

1. Run `/speckit.tasks` to generate detailed task breakdown
2. Run `/speckit.implement` to execute tasks with TDD workflow
3. Create pull request for code review
4. Deploy to staging
5. Verify on production

## Estimated Effort

- **Migration & Model**: 1.5 hours
- **Views (Shop/Category/Product)**: 2 hours
- **Admin Form + Stimulus**: 2 hours
- **SEO Helper**: 0.5 hours
- **Testing & Verification**: 0.5 hours

**Total**: 4-6 hours (including TDD workflow)

## Support

For questions or issues:
- Review spec: `specs/004-product-descriptions/spec.md`
- Review plan: `specs/004-product-descriptions/plan.md`
- Review data model: `specs/004-product-descriptions/data-model.md`
- Check constitution: `.specify/memory/constitution.md`
- CLAUDE.md for Rails development guidance
