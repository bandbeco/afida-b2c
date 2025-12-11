# Legacy Category and Page URL Redirects

**Created:** 2025-12-11
**Status:** Ready for Implementation

## Overview

Add route-based 301 redirects for 9 legacy category URLs and 3 legacy page URLs from the old Wix site (afida.com), plus create 2 new pages (`/accessibility-statement` and `/articles` placeholder).

This complements the existing `UrlRedirect` system which handles 63 product URL redirects via middleware.

## Problem Statement

The legacy Wix site at afida.com used different URL structures:
- Categories: `/category/hot-cups` (legacy) vs `/categories/cups-and-lids` (new)
- Pages: `/branded-packaging` (legacy) vs `/branding` (new)

Search engines, external backlinks, and user bookmarks still point to these legacy URLs. Without redirects, users get 404 errors and SEO authority is lost.

## Proposed Solution

Use Rails route-based redirects (not the existing UrlRedirect model) because:
1. These are static, known mappings that won't change
2. No database overhead for simple path-to-path redirects
3. Keeps `UrlRedirect` model focused on products with variant params
4. No admin UI needed (per requirements)

## Technical Approach

### Redirect Mappings

**Category Redirects (9):**

| Legacy Path | Target Path | Notes |
|-------------|-------------|-------|
| `/category/cold-cups-lids` | `/categories/cups-and-lids` | Consolidated into single category |
| `/category/hot-cups` | `/categories/cups-and-lids` | Consolidated into single category |
| `/category/hot-cup-extras` | `/categories/cups-and-lids` | Consolidated into single category |
| `/category/napkins` | `/categories/napkins` | Direct mapping |
| `/category/pizza-boxes` | `/categories/pizza-boxes` | Direct mapping |
| `/category/straws` | `/categories/straws` | Direct mapping |
| `/category/takeaway-containers` | `/categories/takeaway-containers` | Direct mapping |
| `/category/takeaway-extras` | `/categories/takeaway-extras` | Direct mapping |
| `/category/all-products` | `/shop` | Maps to shop page |

**Page Redirects (3):**

| Legacy Path | Target Path | Notes |
|-------------|-------------|-------|
| `/branded-packaging` | `/branding` | Existing page |
| `/blog` | `/articles` | New placeholder page |
| `/accessibility-statement` | `/accessibility-statement` | New page (same URL) |

### New Pages

**1. Accessibility Statement (`/accessibility-statement`)**
- Standard WCAG 2.1 AA accessibility commitment
- Contact info for reporting issues
- Conformance status and known limitations
- Link from site footer

**2. Articles Placeholder (`/articles`)**
- "Coming Soon" placeholder
- Brief description of future content
- Link back to shop
- `noindex` meta tag until real content added

## Implementation Plan

### Phase 1: Add Route Redirects

**File:** `config/routes.rb`

Add after `root` and before main routes:

```ruby
# =============================================================================
# Legacy URL Redirects (301 Permanent)
# From old Wix site (afida.com) - preserves SEO and backlinks
# =============================================================================

# Legacy category redirects
get "/category/cold-cups-lids", to: redirect("/categories/cups-and-lids", status: 301)
get "/category/hot-cups", to: redirect("/categories/cups-and-lids", status: 301)
get "/category/hot-cup-extras", to: redirect("/categories/cups-and-lids", status: 301)
get "/category/napkins", to: redirect("/categories/napkins", status: 301)
get "/category/pizza-boxes", to: redirect("/categories/pizza-boxes", status: 301)
get "/category/straws", to: redirect("/categories/straws", status: 301)
get "/category/takeaway-containers", to: redirect("/categories/takeaway-containers", status: 301)
get "/category/takeaway-extras", to: redirect("/categories/takeaway-extras", status: 301)
get "/category/all-products", to: redirect("/shop", status: 301)

# Legacy page redirects
get "/branded-packaging", to: redirect("/branding", status: 301)
get "/blog", to: redirect("/articles", status: 301)
```

### Phase 2: Add New Page Routes

**File:** `config/routes.rb`

Add with other page routes:

```ruby
get "accessibility-statement", to: "pages#accessibility_statement"
get "articles", to: "pages#articles"
```

### Phase 3: Add Controller Actions

**File:** `app/controllers/pages_controller.rb`

```ruby
def accessibility_statement
end

def articles
end
```

### Phase 4: Create Accessibility Statement View

**File:** `app/views/pages/accessibility_statement.html.erb`

```erb
<% content_for :title, "Accessibility Statement" %>
<% content_for :meta_description, "Afida's commitment to digital accessibility. Learn about our WCAG 2.1 AA conformance and how to report accessibility issues." %>

<div class="container mx-auto py-8 min-h-screen">
  <div class="prose prose-lg max-w-4xl mx-auto">
    <h1>Accessibility Statement</h1>

    <p class="lead">Afida is committed to ensuring digital accessibility for people with disabilities.</p>

    <h2>Our Commitment</h2>
    <p>We continually improve the user experience for everyone and apply relevant accessibility standards to ensure we provide equal access to all users.</p>

    <h2>Conformance Status</h2>
    <p>We aim to conform to the Web Content Accessibility Guidelines (WCAG) 2.1 Level AA. These guidelines explain how to make web content more accessible for people with disabilities.</p>

    <h2>Measures We Take</h2>
    <ul>
      <li>Include accessibility as part of our development process</li>
      <li>Conduct regular accessibility reviews</li>
      <li>Provide text alternatives for images</li>
      <li>Ensure sufficient colour contrast</li>
      <li>Make all functionality available via keyboard</li>
      <li>Use clear and consistent navigation</li>
    </ul>

    <h2>Feedback</h2>
    <p>We welcome your feedback on the accessibility of our website. If you encounter any barriers or have suggestions for improvement, please contact us:</p>
    <ul>
      <li>Email: <a href="mailto:hello@afida.co.uk">hello@afida.co.uk</a></li>
      <li>Contact form: <a href="/contact">Contact Us</a></li>
    </ul>
    <p>We aim to respond to accessibility feedback within 5 business days.</p>

    <h2>Technical Specifications</h2>
    <p>This website is built using:</p>
    <ul>
      <li>HTML5</li>
      <li>CSS (TailwindCSS)</li>
      <li>JavaScript</li>
      <li>WAI-ARIA for enhanced accessibility</li>
    </ul>

    <p class="text-sm text-gray-500 mt-8">Last updated: December 2025</p>
  </div>
</div>
```

### Phase 5: Create Articles Placeholder View

**File:** `app/views/pages/articles.html.erb`

```erb
<% content_for :title, "Articles - Coming Soon" %>
<% content_for :meta_description, "Afida articles and eco-friendly catering insights coming soon." %>
<% content_for :head do %>
  <meta name="robots" content="noindex, follow">
<% end %>

<div class="pattern-bg pattern-bg-grey min-h-screen">
  <div class="container mx-auto py-16 px-4">
    <div class="max-w-2xl mx-auto text-center">
      <h1 class="text-4xl font-bold mb-6">Articles Coming Soon</h1>

      <p class="text-xl text-gray-600 mb-8">
        We're working on helpful guides and insights about sustainable catering and eco-friendly packaging.
      </p>

      <p class="text-gray-500 mb-8">
        Check back soon for tips on reducing waste, choosing the right packaging, and making your business more sustainable.
      </p>

      <a href="/shop" class="btn btn-primary btn-lg">
        Shop Our Products
      </a>
    </div>
  </div>
</div>
```

### Phase 6: Add Footer Link for Accessibility

**File:** `app/views/shared/_footer.html.erb`

Add to the appropriate footer section:

```erb
<%= link_to "Accessibility", accessibility_statement_path %>
```

## Edge Cases & Considerations

### Query Parameter Preservation

Rails `redirect` helper preserves query parameters by default. Example:
- `/category/hot-cups?utm_source=google` → `/categories/cups-and-lids?utm_source=google`

### Trailing Slashes

Rails strips trailing slashes by default, so both work:
- `/category/hot-cups` → redirects
- `/category/hot-cups/` → redirects (trailing slash stripped first)

### Case Sensitivity

Rails routes are case-sensitive by default:
- `/category/hot-cups` → redirects
- `/CATEGORY/HOT-CUPS` → 404

This matches standard web behaviour. If case-insensitive matching is needed later, can add middleware.

### Redirect Precedence

Route-based redirects are evaluated before the `UrlRedirectMiddleware` (which only handles `/product/*` paths anyway), so no conflict.

## Testing

### Manual Testing Checklist

For each legacy URL, verify:
- [ ] Returns HTTP 301 status code
- [ ] `Location` header points to correct target
- [ ] Query parameters are preserved
- [ ] Target page loads correctly

### Integration Test

**File:** `test/integration/legacy_redirects_test.rb`

```ruby
require "test_helper"

class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  # Category redirects
  test "redirects legacy cold-cups-lids to cups-and-lids" do
    get "/category/cold-cups-lids"
    assert_redirected_to "/categories/cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects legacy hot-cups to cups-and-lids" do
    get "/category/hot-cups"
    assert_redirected_to "/categories/cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects legacy all-products to shop" do
    get "/category/all-products"
    assert_redirected_to "/shop"
    assert_equal 301, response.status
  end

  # Page redirects
  test "redirects branded-packaging to branding" do
    get "/branded-packaging"
    assert_redirected_to "/branding"
    assert_equal 301, response.status
  end

  test "redirects blog to articles" do
    get "/blog"
    assert_redirected_to "/articles"
    assert_equal 301, response.status
  end

  # Query parameter preservation
  test "preserves query parameters on redirect" do
    get "/category/hot-cups?utm_source=google&utm_campaign=test"
    assert_redirected_to "/categories/cups-and-lids?utm_source=google&utm_campaign=test"
  end

  # New pages
  test "accessibility statement page loads" do
    get "/accessibility-statement"
    assert_response :success
    assert_select "h1", "Accessibility Statement"
  end

  test "articles placeholder page loads" do
    get "/articles"
    assert_response :success
    assert_select "h1", "Articles Coming Soon"
  end

  test "articles page has noindex meta tag" do
    get "/articles"
    assert_select 'meta[name="robots"][content="noindex, follow"]'
  end
end
```

## Files Changed

| File | Change |
|------|--------|
| `config/routes.rb` | Add 11 redirect routes + 2 new page routes |
| `app/controllers/pages_controller.rb` | Add `accessibility_statement` and `articles` methods |
| `app/views/pages/accessibility_statement.html.erb` | New file |
| `app/views/pages/articles.html.erb` | New file |
| `app/views/shared/_footer.html.erb` | Add accessibility link |
| `test/integration/legacy_redirects_test.rb` | New file |

## Success Criteria

- [ ] All 9 legacy category URLs return 301 to correct target
- [ ] All 3 legacy page URLs return 301 to correct target
- [ ] Query parameters preserved on all redirects
- [ ] Accessibility statement page renders with proper content
- [ ] Articles placeholder page renders with noindex tag
- [ ] Footer includes accessibility link
- [ ] All integration tests pass

## References

- [Rails Routing Guide - Redirection](https://guides.rubyonrails.org/routing.html#redirection)
- [Google Search Central - Redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects)
- [W3C WAI Accessibility Statement Generator](https://www.w3.org/WAI/planning/statements/generator/)
- Existing redirect system: `app/models/url_redirect.rb`, `app/middleware/url_redirect_middleware.rb`
- Legacy sitemaps: `legacy_urls/*.xml`
