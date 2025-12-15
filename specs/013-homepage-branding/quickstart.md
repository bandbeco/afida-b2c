# Quickstart: Homepage Branding Section Redesign

**Feature**: 013-homepage-branding
**Date**: 2025-12-14

## Overview

This feature redesigns the homepage branding section to be more visually impactful, using a masonry photo collage of real customer-branded products.

## Prerequisites

- Rails development environment running (`bin/dev`)
- No database migrations required
- No new dependencies required

## Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `app/views/pages/partials/_branding.html.erb` | Modify | Replace existing section with new design |
| `test/system/homepage_branding_test.rb` | Create | System tests for the section |

## Implementation Structure

### Section Layout

```
┌─────────────────────────────────────────────────────────────┐
│  SECTION: bg-[#ffb7c5] rounded-3xl                         │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  MASONRY COLLAGE (columns-2 md:columns-3)             │ │
│  │  - 6 customer photos                                   │ │
│  │  - CSS columns for automatic height distribution       │ │
│  │  - Neobrutalist styling (borders, shadows, hover)      │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  HEADLINE                                              │ │
│  │  "Your Brand."                                         │ │
│  │  "Your Cup." (gradient text)                           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  SUPPORTING TEXT                                       │ │
│  │  "No setup fees. UK production. Delivered in 20 days." │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  TRUST BADGES (grid-cols-2 md:grid-cols-4)            │ │
│  │  [UK] [1,000] [20 days] [£0]                          │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CTA BUTTON                                            │ │
│  │  "Start Branding" → /branded_products                 │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key CSS Patterns

**Masonry Collage**:
```html
<div class="columns-2 md:columns-3 gap-3">
  <div class="break-inside-avoid mb-3 group">
    <%= vite_image_tag "images/branding/DSC_XXXX.webp",
        alt: "Customer branded cup",
        class: "w-full rounded-xl border-2 border-black
               group-hover:scale-105 transition-transform duration-300" %>
  </div>
  <!-- 5 more images -->
</div>
```

**Gradient Headline**:
```html
<h2 class="text-4xl sm:text-5xl font-black text-center">
  Your Brand.<br>
  <span class="text-transparent bg-clip-text bg-gradient-to-r from-[#00a86b] to-[#79ebc0]">
    Your Cup.
  </span>
</h2>
```

**Trust Badges**:
```html
<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
  <div class="flex flex-col items-center p-3 rounded-xl bg-[#79ebc0]/20 border-2 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
    <span class="text-2xl mb-1">🇬🇧</span>
    <span class="text-xl font-black">UK</span>
    <span class="text-xs text-neutral-600">Production</span>
  </div>
  <!-- 3 more badges -->
</div>
```

### Images to Use

| Order | File | Alt Text |
|-------|------|----------|
| 1 | DSC_6621.webp | Shakedown branded coffee cup |
| 2 | DSC_6736.webp | OOO Koffee branded cup |
| 3 | DSC_6770.webp | La Gelatiera branded gelato cup |
| 4 | DSC_6872.webp | Collection of branded cups |
| 5 | DSC_7193.webp | La Gelatiera branded cups display |
| 6 | DSC_7239.webp | Branded gelato cups with gelato |

### Trust Badge Content

| Badge | Icon | Value | Label | Background |
|-------|------|-------|-------|------------|
| UK Production | 🇬🇧 | UK | Production | `bg-[#79ebc0]/20` |
| Minimum Order | Box SVG | 1,000 | Minimum units | `bg-[#ffb7c5]/30` |
| Turnaround | Clock SVG | 20 days | Turnaround | `bg-[#fef08a]/40` |
| Setup Fees | Checkmark SVG | £0 | Setup fees | `bg-[#c4b5fd]/30` |

## Testing Approach

### System Tests Required

1. **Collage Rendering**
   - Verify 6 images are present
   - Verify images have alt text
   - Verify neobrutalist styling (borders visible)

2. **Content Verification**
   - Headline "Your Brand." and "Your Cup." present
   - All 4 trust badges visible with correct values
   - CTA button present with correct text

3. **CTA Functionality**
   - "Start Branding" button navigates to `/branded_products`

4. **Responsive Behavior**
   - Mobile viewport: verify layout adapts
   - Desktop viewport: verify full layout

### Test File Structure

```ruby
# test/system/homepage_branding_test.rb
require "application_system_test_case"

class HomepageBrandingTest < ApplicationSystemTestCase
  test "displays branding section with photo collage" do
    visit root_path

    within "#branding" do
      # Verify collage images
      assert_selector "img[alt*='branded']", minimum: 6

      # Verify headline
      assert_text "Your Brand."
      assert_text "Your Cup."

      # Verify trust badges
      assert_text "UK"
      assert_text "1,000"
      assert_text "20 days"
      assert_text "£0"

      # Verify CTA
      assert_link "Start Branding"
    end
  end

  test "CTA navigates to branded products" do
    visit root_path

    within "#branding" do
      click_link "Start Branding"
    end

    assert_current_path branded_products_path
  end
end
```

## Verification Checklist

After implementation, verify:

- [ ] Collage displays 6 photos in masonry layout
- [ ] Images have descriptive alt text
- [ ] Headline displays with gradient on "Your Cup."
- [ ] All 4 trust badges show correct icons, values, and labels
- [ ] CTA button links to `/branded_products`
- [ ] Section maintains pink background (#ffb7c5)
- [ ] Responsive: 2 columns on mobile, 3 on desktop
- [ ] Hover effects work on collage images
- [ ] No console errors
- [ ] Page load time acceptable (<3s)
- [ ] All system tests pass
