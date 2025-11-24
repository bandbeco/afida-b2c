# Category Page Lighthouse Audit & Fix Workflow

**Date:** 2025-11-24
**Target:** Public category pages (customer-facing product browsing pages)
**Page:** `/category/cups-and-lids` (9 products - representative sample)
**Mode:** Desktop
**Goal:** Comprehensive baseline audit + category-by-category fix implementation

---

## 1. Baseline Audit Setup

### What We're Auditing
- **Page:** `/category/cups-and-lids` (9 products, representative sample)
- **Mode:** Desktop (faster execution, clear results)
- **Categories:** Performance, Accessibility, Best Practices, SEO
- **Skipping:** PWA (not applicable to e-commerce site)

### Execution Approach
1. Start local dev server: `bin/dev`
2. Run Lighthouse CLI against `http://localhost:3000/category/cups-and-lids`
3. Generate both HTML report (for exploration) and JSON (for structured analysis)
4. Save baseline results:
   - `docs/audits/category-cups-and-lids-baseline.html`
   - `docs/audits/category-cups-and-lids-baseline.json`

### Initial Analysis
- Review scores across all 4 categories
- Extract specific issues from each category
- Create prioritized fix list organized by Lighthouse category

---

## 2. Category-by-Category Fix Workflow

### Fix Order
1. **Accessibility** - WCAG compliance, screen readers, keyboard navigation, color contrast
2. **SEO** - Meta tags, structured data, semantic HTML, crawlability
3. **Best Practices** - Security, browser compatibility, console errors, deprecated APIs
4. **Performance** - Image optimization, render blocking, JavaScript execution, Core Web Vitals

### Why This Order?
- Accessibility often requires HTML restructuring that impacts SEO
- SEO issues are often quick wins (missing attributes, meta tags)
- Best Practices can affect performance measurements
- Performance last because other fixes might improve it automatically

### Workflow for Each Category
1. Review all issues in that category from baseline audit
2. Create TodoWrite checklist for all fixes in that category
3. Implement fixes one-by-one, marking todos complete
4. Re-run Lighthouse for ONLY that category to verify
5. Document score improvement before moving to next category

### Verification Checkpoints
- After each category fixes: Quick Lighthouse re-run
- Final: Full audit comparing baseline vs. final across all 4 categories

---

## 3. Documentation & Tracking

### Audit Reports Storage
```
docs/audits/
  category-cups-and-lids-baseline.html       # Initial full report
  category-cups-and-lids-baseline.json       # Structured data
  category-cups-and-lids-accessibility.html  # After accessibility fixes
  category-cups-and-lids-seo.html           # After SEO fixes
  category-cups-and-lids-best-practices.html # After best practices fixes
  category-cups-and-lids-final.html         # After all fixes
```

### Progress Tracking
- Use TodoWrite for each category's fix checklist
- Mark fixes complete as you implement them
- One todo per Lighthouse issue (e.g., "Add lang attribute to html tag", "Fix heading hierarchy")

### Final Comparison Document
- Create `docs/audits/category-page-audit-summary.md`
- Include before/after scores for each category
- List all issues fixed
- Note any issues deferred or unresolved
- Lighthouse score changes: Baseline → Final

### Git Commits
- Commit after each category fix batch (e.g., "Fix category page accessibility issues")
- Include Lighthouse scores in commit message for traceability

---

## 4. Technical Implementation

### Lighthouse CLI Setup

**Check installation:**
```bash
npx lighthouse --version
```

**Run baseline audit (desktop mode):**
```bash
npx lighthouse http://localhost:3000/category/cups-and-lids \
  --preset=desktop \
  --output=html,json \
  --output-path=docs/audits/category-cups-and-lids-baseline \
  --chrome-flags="--headless=new"
```

**Category-specific re-runs:**
```bash
# After accessibility fixes (only audit accessibility)
npx lighthouse http://localhost:3000/category/cups-and-lids \
  --preset=desktop \
  --only-categories=accessibility \
  --output=html \
  --output-path=docs/audits/category-cups-and-lids-accessibility

# Repeat for seo, best-practices, performance
```

### Key Lighthouse Flags
- `--preset=desktop` - Desktop throttling and viewport
- `--only-categories=accessibility` - Fast focused re-runs
- `--output=html,json` - Multiple formats
- `--chrome-flags="--headless=new"` - Runs in background

### Server Requirements
- Dev server must be running: `bin/dev`
- Database seeded with products and categories
- Images attached to products (Active Storage)

### Common Issues to Expect
- **Accessibility:** Missing alt text, color contrast, ARIA labels, heading hierarchy
- **SEO:** Missing meta descriptions, structured data issues
- **Best Practices:** Image aspect ratio, console errors
- **Performance:** Image sizes, unused JavaScript, render blocking

---

## 5. Post-Fix & Rollout

### After All Fixes Complete

**1. Final verification audit**
- Run full Lighthouse audit on Cups & Lids page
- Compare final scores to baseline across all 4 categories
- Confirm all critical issues resolved

**2. Spot-check other categories**
- Quick Lighthouse run on 2-3 other categories (e.g., Takeaway Containers, Straws)
- Verify fixes applied globally (shared templates/layouts)
- Identify any category-specific issues missed

**3. Summary document**
- Create `docs/audits/category-page-audit-summary.md`
- Baseline vs Final score table
- Complete list of fixes applied
- Code changes summary (files modified)
- Any known remaining issues or technical debt

**4. Git commit & review**
- Commit final state: "Complete category page Lighthouse audit fixes"
- Include final scores in commit message
- Consider using `superpowers:requesting-code-review` to validate changes

### Success Criteria
- **Accessibility:** 90+ (ideally 100)
- **SEO:** 95+ (you already have good SEO infrastructure)
- **Best Practices:** 90+
- **Performance:** 80+ (desktop should be strong)

---

## Current Category Page Architecture

### Templates
- `app/views/categories/show.html.erb` - Main category page
- `app/views/categories/_index.html.erb` - Category card grid (used on homepage)
- `app/views/products/_product.html.erb` - Individual product cards

### Key Features
- Product grids with images and quick-add functionality
- Category descriptions and icons
- SEO metadata and structured data (CollectionPage schema)
- Cart drawer integration
- Breadcrumb navigation

### Controller
- `CategoriesController#show` - Loads category and products with eager loading

### Categories Available
1. Takeaway Containers (6 products)
2. Cups & Lids (9 products) ← **Audit target**
3. Ice Cream Cups (1 product)
4. Takeaway Extras (8 products)
5. Napkins (6 products)
6. Pizza Boxes (1 product)
7. Straws (5 products)
8. Branded Products (9 products)

---

## Next Steps

1. Start dev server: `bin/dev`
2. Run baseline Lighthouse audit
3. Create TodoWrite checklist for Accessibility fixes
4. Begin category-by-category implementation
