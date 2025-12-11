# Google Business Profile Integration

## Overview

Add Google Business Profile (GBP) integration to Afida's e-commerce site to boost trust signals and SEO through:
1. Enhanced Organization schema with AggregateRating markup
2. Subtle rating badge in footer (site-wide)
3. Very subtle rating badge on homepage under client logos

**Business Context**: Fresh GBP with 2 reviews (growing). Warehouse-only operation (no public storefront). Current trust signals: client logos.

**Strategic Positioning**: Create a "trust stack" hierarchy:
- Client logos (B2B credibility) → Google rating (public validation)

---

## Technical Approach

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Schema type | `Organization` (not `LocalBusiness`) | E-commerce without public storefront; LocalBusiness is for customer-facing locations |
| Configuration storage | Rails credentials | Secure, version-controlled, consistent with existing patterns (Stripe, Mailgun) |
| Caching | Rails cache (Solid Cache) | 12-hour TTL, background refresh every 6 hours |
| Badge interaction | `target="_blank"` to GBP | Opens reviews section, doesn't disrupt shopping flow |
| Minimum threshold | 2 reviews | Show immediately since reviews exist; update to 5 when dynamic widget added |

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Rails Credentials│────▶│ SEO Helper       │────▶│ View Partials   │
│ - place_id      │     │ - gbp_rating_data│     │ - _gbp_badge    │
│ - rating        │     │ - org_schema     │     │ - _footer       │
│ - review_count  │     │                  │     │ - home.html.erb │
│ - profile_url   │     └──────────────────┘     └─────────────────┘
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ JSON-LD Schema  │
│ (in <head>)     │
└─────────────────┘
```

**Phase 1 (Now)**: Static configuration in credentials, manually updated when reviews change.
**Phase 2 (Future)**: Google Places API with background job refresh.

---

## Implementation Phases

### Phase 1: Schema & Static Badges (This Implementation)

#### Task 1.1: Add GBP Configuration to Credentials

**File**: `config/credentials.yml.enc` (via `rails credentials:edit`)

```yaml
google_business:
  place_id: "ChIJ..."  # Your Google Place ID
  rating: 5.0
  review_count: 2
  profile_url: "https://g.page/r/YOUR_REVIEW_URL/review"
```

**Finding your Place ID**:
1. Go to [Google Place ID Finder](https://developers.google.com/maps/documentation/places/web-service/place-id)
2. Search for "Afida" and copy the Place ID

---

#### Task 1.2: Create GBP Helper Methods

**File**: `app/helpers/seo_helper.rb`

Add these methods after the existing `organization_structured_data` method:

```ruby
# GBP rating data accessor with fallback
def gbp_rating_data
  @gbp_rating_data ||= {
    rating: Rails.application.credentials.dig(:google_business, :rating),
    review_count: Rails.application.credentials.dig(:google_business, :review_count),
    profile_url: Rails.application.credentials.dig(:google_business, :profile_url),
    place_id: Rails.application.credentials.dig(:google_business, :place_id)
  }
end

def gbp_configured?
  gbp_rating_data[:rating].present? && gbp_rating_data[:review_count].present?
end

def gbp_profile_url
  gbp_rating_data[:profile_url] || "https://search.google.com/local/reviews?placeid=#{gbp_rating_data[:place_id]}"
end
```

---

#### Task 1.3: Enhance Organization Structured Data

**File**: `app/helpers/seo_helper.rb`

Update `organization_structured_data` method to include AggregateRating:

```ruby
def organization_structured_data
  data = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "Afida",
    "url": root_url,
    "logo": logo_url,
    "description": "Eco-friendly catering supplies for UK businesses",
    "contactPoint": {
      "@type": "ContactPoint",
      "contactType": "Customer Service",
      "email": "hello@afida.com"
    },
    "sameAs": [
      gbp_profile_url
    ].compact
  }

  # Add aggregate rating if GBP is configured
  if gbp_configured?
    data[:aggregateRating] = {
      "@type": "AggregateRating",
      "ratingValue": gbp_rating_data[:rating].to_s,
      "reviewCount": gbp_rating_data[:review_count].to_s,
      "bestRating": "5",
      "worstRating": "1"
    }
  end

  data.to_json
end
```

---

#### Task 1.4: Create GBP Badge Partial

**File**: `app/views/shared/_gbp_badge.html.erb` (new file)

```erb
<%# Google Business Profile rating badge
    Usage: render "shared/gbp_badge", variant: :footer | :homepage
    - :footer - Standard footer styling (site-wide)
    - :homepage - More subtle styling (under client logos)
%>
<% if gbp_configured? %>
  <% variant ||= :footer %>
  <%
    link_classes = case variant
    when :homepage
      "inline-flex items-center gap-1 text-xs text-base-content/60 hover:text-base-content/80 transition-colors"
    else # :footer
      "inline-flex items-center gap-1.5 text-sm text-base-content/70 hover:text-base-content transition-colors"
    end

    star_classes = case variant
    when :homepage
      "w-3 h-3 text-amber-400"
    else
      "w-4 h-4 text-amber-400"
    end
  %>

  <%= link_to gbp_profile_url,
      target: "_blank",
      rel: "noopener noreferrer",
      class: link_classes,
      aria: { label: "Rated #{number_with_precision(gbp_rating_data[:rating], precision: 1)} out of 5 stars on Google Business Profile, based on #{gbp_rating_data[:review_count]} reviews. Opens in new tab." },
      data: {
        turbo: false,
        controller: "analytics",
        action: "click->analytics#track",
        analytics_event_param: "click_gbp_badge",
        analytics_location_param: variant.to_s
      } do %>
    <%# Star icon %>
    <svg class="<%= star_classes %>" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
    </svg>

    <%# Rating text %>
    <span>
      <%= number_with_precision(gbp_rating_data[:rating], precision: 1) %> on Google
    </span>
  <% end %>
<% end %>
```

---

#### Task 1.5: Add Badge to Footer

**File**: `app/views/shared/_footer.html.erb`

Add badge after the payment methods section (around line 66), inside the copyright row:

Find this section:
```erb
<div class="flex flex-col md:flex-row items-center justify-between gap-4">
  <%# Left side - logo and copyright %>
  <div class="flex items-center gap-3">
    ...
  </div>
  <%# Right side - payment methods %>
  <%= render "shared/payment_methods" %>
</div>
```

Update to:
```erb
<div class="flex flex-col md:flex-row items-center justify-between gap-4">
  <%# Left side - logo and copyright %>
  <div class="flex items-center gap-3">
    <%= link_to root_path do %>
      <%= image_tag "afida-logo.svg", alt: "Afida", class: "h-6 w-auto" %>
    <% end %>
    <span class="text-sm text-base-content/70">© <%= Date.current.year %> Afida. All rights reserved.</span>
  </div>

  <%# Right side - payment methods and GBP badge %>
  <div class="flex items-center gap-6">
    <%= render "shared/gbp_badge", variant: :footer %>
    <%= render "shared/payment_methods" %>
  </div>
</div>
```

---

#### Task 1.6: Add Badge to Homepage

**File**: `app/views/pages/home.html.erb`

Add badge section after client logos (around line 24):

Find:
```erb
<%= render "pages/partials/client_logos" %>
```

Add after:
```erb
<%= render "pages/partials/client_logos" %>

<%# Google Business Profile trust signal - subtle, under client logos %>
<% if gbp_configured? %>
  <div class="bg-white py-2 text-center">
    <%= render "shared/gbp_badge", variant: :homepage %>
  </div>
<% end %>
```

---

#### Task 1.7: Add Helper Tests

**File**: `test/helpers/seo_helper_test.rb`

Add these test cases:

```ruby
test "gbp_rating_data returns credentials data" do
  # This test verifies the helper reads from credentials
  # In test environment, credentials may not have GBP data
  data = gbp_rating_data
  assert data.is_a?(Hash)
  assert data.key?(:rating)
  assert data.key?(:review_count)
  assert data.key?(:profile_url)
  assert data.key?(:place_id)
end

test "gbp_configured? returns false when rating is missing" do
  # Mock credentials to return nil
  Rails.application.credentials.stubs(:dig).with(:google_business, :rating).returns(nil)
  Rails.application.credentials.stubs(:dig).with(:google_business, :review_count).returns(5)

  refute gbp_configured?
end

test "gbp_configured? returns true when rating and review_count present" do
  Rails.application.credentials.stubs(:dig).with(:google_business, :rating).returns(4.8)
  Rails.application.credentials.stubs(:dig).with(:google_business, :review_count).returns(12)
  Rails.application.credentials.stubs(:dig).with(:google_business, :profile_url).returns("https://g.page/test")
  Rails.application.credentials.stubs(:dig).with(:google_business, :place_id).returns("ChIJtest")

  assert gbp_configured?
end

test "organization_structured_data includes aggregateRating when gbp configured" do
  Rails.application.credentials.stubs(:dig).with(:google_business, :rating).returns(5.0)
  Rails.application.credentials.stubs(:dig).with(:google_business, :review_count).returns(2)
  Rails.application.credentials.stubs(:dig).with(:google_business, :profile_url).returns("https://g.page/test")
  Rails.application.credentials.stubs(:dig).with(:google_business, :place_id).returns("ChIJtest")

  json = organization_structured_data
  data = JSON.parse(json)

  assert data["aggregateRating"].present?
  assert_equal "AggregateRating", data["aggregateRating"]["@type"]
  assert_equal "5.0", data["aggregateRating"]["ratingValue"]
  assert_equal "2", data["aggregateRating"]["reviewCount"]
end

test "organization_structured_data includes sameAs with GBP profile" do
  Rails.application.credentials.stubs(:dig).with(:google_business, :rating).returns(5.0)
  Rails.application.credentials.stubs(:dig).with(:google_business, :review_count).returns(2)
  Rails.application.credentials.stubs(:dig).with(:google_business, :profile_url).returns("https://g.page/test")
  Rails.application.credentials.stubs(:dig).with(:google_business, :place_id).returns("ChIJtest")

  json = organization_structured_data
  data = JSON.parse(json)

  assert data["sameAs"].present?
  assert data["sameAs"].include?("https://g.page/test")
end
```

---

#### Task 1.8: Add System Test for Badge Rendering

**File**: `test/system/gbp_badge_test.rb` (new file)

```ruby
require "application_system_test_case"

class GbpBadgeTest < ApplicationSystemTestCase
  test "homepage displays GBP badge under client logos when configured" do
    # Skip if GBP not configured in test environment
    skip "GBP not configured" unless Rails.application.credentials.dig(:google_business, :rating)

    visit root_path

    # Find the badge
    badge = find('a[aria-label*="Google Business Profile"]', match: :first)

    assert badge.present?
    assert badge.text.include?("on Google")
    assert badge[:target] == "_blank"
    assert badge[:rel].include?("noopener")
  end

  test "footer displays GBP badge on all pages" do
    skip "GBP not configured" unless Rails.application.credentials.dig(:google_business, :rating)

    visit products_path

    within "footer" do
      badge = find('a[aria-label*="Google Business Profile"]')
      assert badge.present?
    end
  end

  test "GBP badge has proper accessibility attributes" do
    skip "GBP not configured" unless Rails.application.credentials.dig(:google_business, :rating)

    visit root_path

    badge = find('a[aria-label*="Google Business Profile"]', match: :first)

    # Check aria-label contains rating info
    aria_label = badge["aria-label"]
    assert aria_label.include?("Rated")
    assert aria_label.include?("out of 5 stars")
    assert aria_label.include?("Opens in new tab")
  end
end
```

---

#### Task 1.9: Validate Structured Data

After deployment, validate the implementation:

1. **Google Rich Results Test**: https://search.google.com/test/rich-results
   - Enter your homepage URL
   - Verify Organization schema is detected
   - Verify AggregateRating is present

2. **Schema.org Validator**: https://validator.schema.org/
   - Paste your page URL
   - Check for any errors or warnings

3. **Google Search Console**:
   - Submit sitemap
   - Monitor for structured data errors in "Enhancements" section

---

### Phase 2: Dynamic Widget (Future - When 8-10+ Reviews)

This phase will be planned separately when review threshold is reached. High-level approach:

1. **Google Places API Integration**
   - Store Place ID in credentials (already done)
   - Create `GooglePlacesService` for API calls
   - Implement rate limiting and error handling

2. **Background Job for Cache Refresh**
   - Solid Queue job running every 6 hours
   - Update cached rating/review count
   - Alert admin if API fails repeatedly

3. **Dynamic Reviews Widget**
   - Display actual review snippets
   - Rotating testimonials carousel
   - "Write a review" CTA

4. **Admin Dashboard**
   - View current rating/review count
   - Manual refresh button
   - Enable/disable widget toggle

---

## Acceptance Criteria

### Functional Requirements

- [ ] GBP badge displays in footer on all pages when configured
- [ ] GBP badge displays on homepage under client logos when configured
- [ ] Badge links to Google Business Profile (opens in new tab)
- [ ] Badge shows current rating with one decimal place (e.g., "5.0")
- [ ] Badge gracefully hidden when credentials not configured
- [ ] Organization schema includes AggregateRating
- [ ] Organization schema includes sameAs linking to GBP profile

### Accessibility Requirements

- [ ] Badge has descriptive aria-label with full rating info
- [ ] Badge is keyboard focusable with visible focus indicator
- [ ] Star icon has aria-hidden="true"
- [ ] Link announces "opens in new tab" for screen readers
- [ ] Minimum 44x44px tap target on mobile (achieved via padding)

### Visual Requirements

- [ ] Footer badge: `text-sm`, amber star, 70% opacity text
- [ ] Homepage badge: `text-xs`, smaller star, 60% opacity text (more subtle)
- [ ] Hover state increases opacity/color
- [ ] Consistent with existing Afida design system

### Testing Requirements

- [ ] Helper tests pass for GBP data methods
- [ ] Helper tests verify schema includes AggregateRating
- [ ] System tests verify badge renders on homepage and footer
- [ ] System tests verify accessibility attributes
- [ ] Manual validation with Google Rich Results Test

---

## Configuration Checklist

Before deploying, ensure these are configured:

```bash
# 1. Find your Google Place ID
# Visit: https://developers.google.com/maps/documentation/places/web-service/place-id
# Search for your business and copy the Place ID

# 2. Get your Google Business Profile review URL
# Go to your GBP dashboard → Get more reviews → Copy link

# 3. Add to credentials
rails credentials:edit
```

Add this section:
```yaml
google_business:
  place_id: "ChIJxxxxxxxxxxxxx"
  rating: 5.0
  review_count: 2
  profile_url: "https://g.page/r/xxxxx/review"
```

---

## Updating Rating Data (Manual Process)

Until dynamic widget is implemented, update rating manually:

1. Check current rating on Google Business Profile
2. Run `rails credentials:edit`
3. Update `rating` and `review_count` values
4. Deploy changes

**Recommended frequency**: Weekly check, or when you receive email notification of new review.

---

## References

### Internal Files
- SEO Helper: `app/helpers/seo_helper.rb`
- Footer: `app/views/shared/_footer.html.erb`
- Homepage: `app/views/pages/home.html.erb`
- Client Logos: `app/views/pages/partials/_client_logos.html.erb`
- Existing star SVG pattern: `app/views/pages/partials/_testimonials.html.erb:12-16`

### External Documentation
- [Schema.org Organization](https://schema.org/Organization)
- [Schema.org AggregateRating](https://schema.org/AggregateRating)
- [Google Structured Data Guidelines](https://developers.google.com/search/docs/appearance/structured-data/organization)
- [Google Rich Results Test](https://search.google.com/test/rich-results)
- [Google Place ID Finder](https://developers.google.com/maps/documentation/places/web-service/place-id)

### Research Notes
- Self-serving review snippets (reviews on own site about own business) don't qualify for rich results as of 2024
- Organization schema preferred over LocalBusiness for e-commerce without public storefront
- AggregateRating requires visible rating on page where schema appears
