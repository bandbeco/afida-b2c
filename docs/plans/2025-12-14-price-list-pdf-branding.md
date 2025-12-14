# Price List PDF Branding Enhancement

**Date:** 14 December 2025
**Status:** Implemented
**Goal:** Transform the price list PDF from a basic functional document into a professional, promotional asset

## Problem Statement

The current PDF price list (`PriceListPdf` service) is purely functional with:
- Plain text header ("Afida Price List")
- No logo or branding
- Minimal footer (just page numbers)

This misses an opportunity to reinforce brand identity and communicate key value propositions to prospects who may be receiving the PDF as a first touchpoint.

## Solution Overview

Enhance the PDF with:
1. **Afida logo** in the header (top-left positioning)
2. **Title and metadata** aligned with logo (right side of header)
3. **Value propositions** prominently displayed below the logo
4. **Branded footer** with contact information on every page

## Final Implementation

### Header Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ [LOGO]                              Price List                  │
│ (~65pt height)                      All products                │
│                                     Generated: 14 December 2025 │
│                                     All prices exclude VAT      │
├─────────────────────────────────────────────────────────────────┤
│ Free UK delivery over £100 • Low MOQs • 48-hour delivery        │
└─────────────────────────────────────────────────────────────────┘
```

**Elements:**

- **Logo:**
  - File: `app/frontend/images/afida-logo-pdf.png`
  - Position: Top-left (0, cursor)
  - Height: 65pt (width auto-scales)

- **Title and Metadata:**
  - Position: Right side of header, aligned with logo (x=400)
  - Title: "Price List" (20pt bold)
  - Filter description, generation date, VAT notice (10pt gray)

- **Value Propositions:**
  - Text: "Free UK delivery over £100 • Low MOQs • 48-hour delivery"
  - Position: Below the logo section
  - Font: 11pt bold, black

- **Spacing:** 15pt gap between value props and price table

### Footer Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  [Price table content above]                                    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  afida.com  •  hello@afida.com  •  0203 302 7719    Page 1 of 4 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Elements:**

- **Horizontal Line:**
  - Stroke: 1pt, light gray (#DDDDDD)
  - Position: 40pt from bottom of page
  - Full width (left margin to right margin)

- **Contact Information:**
  - Text: "afida.com • hello@afida.com • 0203 302 7719"
  - Position: Left-aligned with 30pt padding, 20pt from bottom
  - Font: 9pt regular, dark gray (#666666)

- **Page Numbers:**
  - Text: "Page X of Y"
  - Position: Right-aligned, 20pt from bottom
  - Font: 9pt regular, dark gray (#666666)

- **Repeats on every page** using `repeat(:all, dynamic: true)`

### Typography & Colors

- **Logo:** Full color (mint green #79ebc0 with black outline)
- **Value props:** Black (#000000), bold weight
- **Title:** Black (#000000), bold
- **Metadata:** Gray (#666666), regular
- **Footer line:** Light gray (#DDDDDD)
- **Footer text:** Dark gray (#666666)

## Technical Implementation

### File Modified

- `app/services/price_list_pdf.rb`

### Class Constants

All configuration values are extracted to class constants for maintainability:

```ruby
# Layout constants
PAGE_MARGIN_TOP = 30
PAGE_MARGIN_RIGHT = 30
PAGE_MARGIN_BOTTOM = 50  # Extra space reserved for footer
PAGE_MARGIN_LEFT = 30

# Header constants
LOGO_HEIGHT = 65
LOGO_PATH = "app/frontend/images/afida-logo-pdf.png"
TITLE_X_POSITION = 400

# Footer constants
FOOTER_LINE_Y = 40
FOOTER_TEXT_Y = 20
FOOTER_LEFT_PADDING = 30
FOOTER_PAGE_NUMBER_OFFSET = 80

# Branding content
VALUE_PROPOSITIONS = "Free UK delivery over £100 • Low MOQs • 48-hour delivery"
CONTACT_INFO = "afida.com  •  hello@afida.com  •  0203 302 7719"
```

### Prawn Methods Used

All methods are built into Prawn (no new dependencies):

- `image(path, options)` — Logo embedding
- `bounding_box(coordinates) { }` — Positioning title/metadata beside logo
- `repeat(:all, dynamic: true) { }` — Footer on every page with dynamic page numbers
- `canvas { }` — Absolute positioning for footer that doesn't interfere with content
- `stroke_horizontal_line(x1, x2, options)` — Footer separator line
- `draw_text(text, options)` — Absolute positioning for footer elements
- `page_number` and `page_count` — Dynamic page numbering

### Key Implementation Details

1. **Reserved bottom margin:** Increased from 30pt to 50pt to prevent table content from overlapping footer

2. **Canvas for footer:** Using `canvas` inside `repeat` creates an absolute positioning layer that renders behind the main content flow

3. **Dynamic page numbers:** The `dynamic: true` option on `repeat` ensures `page_number` and `page_count` evaluate correctly per-page

## Testing Checklist

- [x] Generate PDF with 1 page of results (verify header/footer fit)
- [x] Generate PDF with 4+ pages (verify footer repeats on all pages)
- [x] Generate filtered PDF (verify filter description displays correctly)
- [x] Test with "All products" filter (verify metadata text)
- [x] Check logo aspect ratio (not distorted)
- [x] Verify contact info is readable at 9pt
- [x] Verify page numbers show correct values on all pages
- [x] No content/footer overlap on any page

## Success Criteria

✅ Logo appears clearly in top-left of first page header
✅ Title and metadata appear on the right side, aligned with logo
✅ Value propositions are prominent and readable below the logo
✅ Contact information appears in footer of every page
✅ Page numbers correctly show "Page X of Y" format
✅ Document maintains professional appearance when printed
✅ No content overflow or layout issues with varying data volumes

## Future Enhancements (Out of Scope)

- Custom logo variants for different customer segments
- QR code linking to product catalog
- Promotional banner for seasonal offers
- Product category thumbnails or icons
- Migration to Grover for HTML/CSS-based PDF rendering
