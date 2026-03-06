# PRD: Afida Navigation Redesign
**Version:** 2.0
**Date:** 6 March 2026
**Author:** Margot (AI), revised with Laurent
**Stakeholders:** Tariq Adam, Laurent Curau

---

## 1. Overview

Afida's current navigation has a flat toolbar with 7 hardcoded categories, no dropdowns, and no subcategory structure. Customers must click into a category and scroll through all products to find what they need. This hurts conversion and user experience.

This PRD defines the requirements for a full navigation redesign:
- Desktop mega-menu dropdowns (click-to-open)
- Mobile drill-down navigation
- Updated category hierarchy with subcategories
- Vegware surfaced as a collection with dedicated SEO pages

---

## 2. Problem Statement

### Current Issues
- **No dropdowns:** 7 categories in a flat sub-nav bar with no subcategory access
- **No filtering within categories:** Customers scroll through all products with no way to narrow down
- **Overlapping categories:** "Takeaway Containers" and "Takeaway Extras" are vague and overlap
- **Missing ranges:** Vegware (hundreds of products) has no dedicated navigation destination
- **Competitive gap:** All major competitors have dropdown menus

### Impact
- Customers unable to quickly find products — higher bounce rate
- Poor UX discourages repeat visits
- SEO opportunity missed — granular subcategory pages can rank for specific keywords

---

## 3. Goals

1. Reduce time-to-product for all customer types
2. Match or exceed competitor navigation standards
3. Eliminate overlapping/confusing categories
4. Surface the Vegware range as a distinct destination
5. Support future catalogue growth without nav restructure

---

## 4. Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Avg. clicks to product | 3-4 | 2 |
| Bounce rate on category pages | -- | -15% |
| Category page session depth | -- | +20% |
| Mobile nav completion rate | -- | Baseline + improve |

---

## 5. Navigation Layout

### 5.1 Two-Bar Desktop Navigation

The existing two-bar layout is retained and enhanced.

**Top bar (utility/brand nav):**
```
[Logo]   Shop All | Collections | Free Samples | Branding | Price List   [Search] [Cart] [Account]
```

- "Shop All" links to `/shop` (existing product browse page with search and filters)
- "Collections" retains the existing hover mega-menu showing curated collections with image previews
- Account dropdown (avatar) shows: Admin Panel, My Branded Products, Account Settings, Addresses, Orders, Scheduled Reorders, Logout
- Sign In / Sign Up buttons shown when logged out

**Category bar (product browsing, click-to-open mega-menu):**
```
Cups & Drinks | Hot Food | Cold Food & Salads | Tableware | Bags & Wraps | Supplies & Essentials | Vegware | Branded Packaging
```

- Each label is a `<button>` that opens a mega-menu panel on click
- Top-level items display an SVG icon + text label
- Subcategories inside the panel are text-only links
- "View all [category]" link at the bottom of each panel
- Category label is NOT a link — clicking opens the dropdown only

### 5.2 Desktop Mega-Menu Behaviour

- **Click-to-open** (not hover)
- Full-width panel showing subcategories in a grid layout
- Backdrop overlay dims the rest of the page
- Close on: clicking outside, pressing Escape, clicking another category button
- Keyboard accessible: `aria-expanded`, `aria-haspopup`, arrow key navigation within panels, Tab through subcategory links, Escape closes and returns focus to trigger
- Responsive breakpoint: mega-menu on desktop (>= 768px), mobile menu below

### 5.3 Mobile Navigation

Hamburger menu opens a slide-in drill-down panel. The mobile category pill bar (horizontal scroll) is removed entirely.

**Structure:**
```
[X Close]
  Shop All
  Cups & Drinks          >
  Hot Food               >
  Cold Food & Salads     >
  Tableware              >
  Bags & Wraps           >
  Supplies & Essentials  >
  Vegware                >
  Branded Packaging      >
  ---
  Free Samples
  Price List
  ---
  Orders
  Scheduled Reorders
  Addresses
  Account Settings
  Logout
```

(Sign In / Sign Up replaces the account section when logged out)

**Requirements:**
- Smooth slide-in animation
- Back button to return to top level
- Max 2 levels deep (top-level -> subcategory -> products)
- Same category/subcategory structure as desktop
- Close on outside tap or X button
- Tapping a category with `>` reveals its subcategories

---

## 6. Category & Subcategory Structure

### 6.1 Data Model

Self-referential `Category` model with `parent_id` column:

- Top-level categories: `parent_id: nil`
- Subcategories: `parent_id` references a top-level category
- `Product belongs_to :category` (always points to a leaf-level subcategory)
- `product.category` returns the subcategory
- `product.category.parent` returns the top-level category
- Products are ordered within subcategory via `acts_as_list scope: :category`

Scopes:
- `Category.where(parent_id: nil)` — top-level categories
- `Category.where.not(parent_id: nil)` — subcategories
- `category.children` — subcategories of a parent

### 6.2 Top-Level Categories (7 real + 1 collection)

| # | Category | Type | Subcategories |
|---|----------|------|---------------|
| 1 | Cups & Drinks | Real category | 6 |
| 2 | Hot Food | Real category | 5 |
| 3 | Cold Food & Salads | Real category | 3 |
| 4 | Tableware | Real category | 4 |
| 5 | Bags & Wraps | Real category | 3 |
| 6 | Supplies & Essentials | Real category | 4 |
| 7 | Vegware | Collection (brand filter) | Filtered views |
| 8 | Branded Packaging | Real category | 2 |

### 6.3 Full Subcategory Map (27 total)

**Cups & Drinks**
| Subcategory | Contains |
|---|---|
| Hot Cups | Single wall, double wall, ripple wall cups |
| Cold Cups | Cold cups, smoothie cups |
| Ice Cream Cups | Ice cream tubs, lids, dessert cups |
| Cup Lids | Bagasse, PP, PLA lids |
| Straws | Paper, bamboo, bio fibre straws |
| Cup Accessories | Carriers, stirrers, sleeves, sugar sticks |

**Hot Food**
| Subcategory | Contains |
|---|---|
| Pizza Boxes | 7" to 16" kraft pizza boxes |
| Takeaway Boxes | Kraft takeaway boxes (No.1, No.8, etc.) |
| Food Containers | Kraft bowls (round, rectangular), microwaveable containers |
| Soup Containers | Kraft soup containers + lids |
| Bagasse Containers | Bagasse/sugarcane range |

**Cold Food & Salads**
| Subcategory | Contains |
|---|---|
| Salad Boxes | Salad bowls, deli containers |
| Sandwich & Wrap Boxes | Sandwich wedges, baguette trays, tortilla cartons |
| Deli Pots | Portion pots, deli pots |

**Tableware**
| Subcategory | Contains |
|---|---|
| Plates & Trays | Chip trays, food trays |
| Cutlery | Wooden cutlery kits, forks, knives, spoons |
| Napkins | Cocktail, dinner, airlaid, dispenser napkins |
| Aluminium Containers | Containers + lids |

**Bags & Wraps**
| Subcategory | Contains |
|---|---|
| Bags | Flat handle, twisted handle, carrier bags |
| Greaseproof & Wraps | Burger wraps, greaseproof sheets, gingham sheets, deli wraps |
| NatureFlex Bags | Bloomer bags, natureflex bags |

**Supplies & Essentials**
| Subcategory | Contains |
|---|---|
| Bin Liners | Vegware Completely Liners (8L-240L) |
| Labels & Stickers | Day rotation labels, allergen labels, Vegware stickers |
| Gloves & Cleaning | Food handling gloves, centrefeed rolls, release agent |
| Till Rolls | Thermal till/PDQ rolls |

**Branded Packaging**
| Subcategory | Contains |
|---|---|
| Branded Cups | Custom printed single/double wall cups |
| Branded Greaseproof | Custom printed greaseproof paper |

### 6.4 Category Consolidation (Migration)

| Current Category | Action | New Home |
|---|---|---|
| Cups & Lids | Split | Cups & Drinks -> Hot Cups, Cold Cups, Cup Lids (by product type) |
| Ice Cream Cups | Move | Cups & Drinks -> Ice Cream Cups |
| Napkins | Move | Tableware -> Napkins |
| Pizza Boxes | Move | Hot Food -> Pizza Boxes |
| Straws | Move | Cups & Drinks -> Straws |
| Takeaway Containers | Split | Hot Food -> Takeaway Boxes, Food Containers, Soup Containers |
| Takeaway Extras | Kill & distribute | Products distributed to relevant subcategories (see Section 6.5) |

### 6.5 Takeaway Extras Distribution

Products from the killed "Takeaway Extras" category are distributed as follows:

| Product Group | New Home |
|---|---|
| Stirrers (wood, Vegware) | Cups & Drinks -> Cup Accessories |
| Cup carriers (pulp, Vegware) | Cups & Drinks -> Cup Accessories |
| Cup sleeves (Vegware) | Cups & Drinks -> Cup Accessories |
| Bags (flat handle, twisted handle) | Bags & Wraps -> Bags |
| Wooden cutlery (forks, knives, spoons, kits) | Tableware -> Cutlery |
| Burger wraps / greaseproof sheets | Bags & Wraps -> Greaseproof & Wraps |
| Microwaveable containers | Hot Food -> Food Containers |
| Aluminium container lids | Tableware -> Aluminium Containers |
| Labels & stickers (day rotation, allergen) | Supplies & Essentials -> Labels & Stickers |
| Food handling gloves | Supplies & Essentials -> Gloves & Cleaning |
| Blue centrefeed rolls | Supplies & Essentials -> Gloves & Cleaning |
| Till rolls | Supplies & Essentials -> Till Rolls |
| Sandwich packaging (cards, wedges, tortilla) | Cold Food & Salads -> Sandwich & Wrap Boxes |
| Bin liners (Vegware Completely Liners) | Supplies & Essentials -> Bin Liners |
| Foil deli wraps | Bags & Wraps -> Greaseproof & Wraps |
| Sugar sticks (Vegware) | Supplies & Essentials -> (kitchen ops item) |
| Vegware stickers | Supplies & Essentials -> Labels & Stickers |

---

## 7. Vegware

### Concept

Vegware is a **brand**, not a product type. It is implemented as a `Collection`, not a category. Products belong to their real functional subcategory (e.g., Hot Cups, Straws, Napkins) and are identified as Vegware via the `brand` field on the `Product` model.

### Navigation

Vegware appears as a top-level item in the category bar. Clicking it opens a mega-menu showing filtered views by parent category (e.g., "Vegware Cups & Drinks", "Vegware Tableware").

### URL Structure

Vegware SEO pages use nested collection routes:

```
/collections/vegware                          -> All Vegware products
/collections/vegware/cups-and-drinks          -> Vegware products in Cups & Drinks
/collections/vegware/tableware                -> Vegware products in Tableware
```

Each page gets a unique URL, H1, and meta description for SEO.

### Implementation

- Create a Vegware `Collection` record
- Populate via `CollectionItem` join table for all products where `brand = "Vegware"`
- Add nested route: `resources :collections { get ':category_slug', action: :show, as: :category_filter, on: :member }`
- Controller filters: `collection.products.joins(:category).where(categories: { parent_id: category.id })`

---

## 8. URL Structure & Redirects

### New URL Pattern

```
/categories/:parent_slug/:subcategory_slug
```

Examples:
- `/categories/cups-and-drinks/hot-cups`
- `/categories/hot-food/pizza-boxes`
- `/categories/tableware/napkins`
- `/categories/supplies-and-essentials/bin-liners`

Parent category pages (showing all products in all subcategories):
- `/categories/cups-and-drinks`
- `/categories/hot-food`

### 301 Redirects Required

| Old URL | New URL |
|---|---|
| `/categories/cups-and-lids` | `/categories/cups-and-drinks` |
| `/categories/ice-cream-cups` | `/categories/cups-and-drinks/ice-cream-cups` |
| `/categories/napkins` | `/categories/tableware/napkins` |
| `/categories/pizza-boxes` | `/categories/hot-food/pizza-boxes` |
| `/categories/straws` | `/categories/cups-and-drinks/straws` |
| `/categories/takeaway-containers` | `/categories/hot-food` |
| `/categories/takeaway-extras` | `/categories/supplies-and-essentials` |

Legacy `/category/*` redirects (already in routes.rb) must be updated to chain through to the new URLs instead of pointing to now-dead intermediate URLs.

### SEO Requirements

- Each subcategory page gets its own URL, H1, and meta tags
- Old category URLs must 301 redirect (never 404)
- Vegware collection pages get unique meta tags per category filter
- SEO copy for new subcategory pages (separate task, written by Margot)

---

## 9. Shop All Page

The existing `/shop` page is retained as-is. It provides:
- Full product catalogue with search
- Category filter sidebar (updated to reflect new subcategory structure)
- Option filters (size, colour, material)
- Sort controls

No standalone icon grid page is created. The mega-menu itself serves as the visual category directory.

---

## 10. Collections

Collections are a separate concept from categories and are retained unchanged.

- **Collections** slice the catalogue horizontally (by audience/context): "Coffee Shop Essentials", etc.
- **Categories** slice vertically (by product type): "Hot Cups", "Pizza Boxes", etc.
- The existing Collections mega-menu in the top nav bar stays as-is
- Vegware is implemented as a collection (see Section 7)

---

## 11. Icons

- Top-level category buttons in the category bar display SVG icon + text label
- Subcategory links inside mega-menu panels are text-only
- Existing SVG icons are reused where applicable (mapped via `CategoriesHelper::CATEGORY_ICONS`)
- The default fallback icon (`box.svg`) is used for new categories until custom SVGs are created
- 7-8 new top-level icons needed; creation is a separate task

---

## 12. Branded Packaging

Branded Packaging is a shoppable catalogue of custom-printed products. It is a real category with its own subcategories, kept separate from non-branded products.

Current range (show only what exists):
- Branded Cups (custom printed single/double wall)
- Branded Greaseproof (custom printed greaseproof paper)

The mega-menu dropdown expands as the branded range grows.

---

## 13. Technical Requirements

### Frontend
- Mega-menu: Stimulus controller (extend existing `mega_menu_controller.js`), click-to-open
- Mobile menu: new slide-in drill-down panel with back navigation
- Category bar: replace current `_category_nav.html.erb` (flat links -> mega-menu buttons)
- Top bar: update `_navbar.html.erb` mobile hamburger (flat list -> drill-down with account links)
- Remove mobile category pill bar
- Responsive breakpoint at 768px

### Backend / Data
- Add `parent_id` column to `categories` table (self-referential)
- Create top-level parent categories, set `parent_id` on existing/new subcategories
- Reassign all ~661 products to leaf-level subcategories
- Kill "Takeaway Extras" category, distribute products
- Create "Supplies & Essentials" category with subcategories
- Create Vegware `Collection` + populate `CollectionItem` records via `brand: "Vegware"`
- Add nested collection route for Vegware SEO pages
- Update 301 redirects in `routes.rb`
- Update `CategoriesHelper` (icon map, related categories, pastel colors)

### Existing Code Affected
- `app/models/category.rb` — add `parent_id`, `has_many :children`, `belongs_to :parent`
- `app/models/product.rb` — `belongs_to :category` stays (now points to subcategory)
- `app/views/shared/_navbar.html.erb` — mobile menu restructure
- `app/views/shared/_category_nav.html.erb` — full rewrite (flat links -> mega-menu)
- `app/views/shared/_collections_mega_menu.html.erb` — retained, no changes
- `app/frontend/javascript/controllers/mega_menu_controller.js` — adapt for click-to-open, reuse for category dropdowns
- `app/helpers/categories_helper.rb` — update icon map, related categories
- `app/views/pages/shop.html.erb` — update category filter sidebar for new structure
- `app/controllers/collections_controller.rb` — add category filter action for Vegware SEO pages
- `config/routes.rb` — update redirects, add nested category/collection routes

---

## 14. Out of Scope (v1)

- Product filtering/faceted search within category pages (future phase)
- Personalisation or "recently viewed" (future phase)
- Custom SVG icons for all 27 subcategories (future — using text-only for now)
- Standalone icon grid page (dropped — mega-menu serves this purpose)

---

## 15. Open Questions (Resolved)

| Question | Decision |
|---|---|
| Subcategory model: new table or self-referential? | Self-referential `Category` with `parent_id` |
| Vegware: category or collection? | Collection, filtered by `brand` field |
| Hover or click mega-menu? | Click-to-open |
| Custom icons or emojis? | SVGs for top-level, text-only subcategories, fallback icon for new categories |
| Standalone Shop All grid page? | No — keep existing `/shop`, mega-menu serves as visual directory |
| Mobile category pill bar? | Removed — categories move into hamburger drill-down |
| Account links on mobile? | Included in mobile menu |
| Collections kept? | Yes — separate concept from categories |
| Vegware SEO URLs? | `/collections/vegware/:category_slug` |
| URL structure? | Nested: `/categories/:parent/:subcategory` |

---

## 16. Priority

| Task | Priority | Effort |
|------|----------|--------|
| Add `parent_id` to Category model | High | Low |
| ~~Category consolidation & product reassignment~~ | ~~High~~ | ~~Done~~ |
| Desktop mega-menu (click-to-open) | High | Medium |
| Mobile drill-down nav | High | Medium |
| ~~301 redirects for old category URLs~~ | ~~High~~ | ~~Done~~ |
| Vegware collection + SEO pages | Medium | Low |
| Update `/shop` page filters for new structure | Medium | Low |
| SEO copy for new subcategory pages | Medium | Low (Margot) |
| New SVG icons for top-level categories | Medium | Low (Design) |
| Update `CategoriesHelper` mappings | Medium | Low |
| Product filtering on category pages | Future | High |
