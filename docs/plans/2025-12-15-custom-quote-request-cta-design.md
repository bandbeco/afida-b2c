# Custom Quote Request CTA - Design Document

## Overview

Add a call-to-action on product pages that links shoppers to the contact page when they can't find what they need. This captures leads from shoppers who need custom sizes, quantities, or materials not available in standard product options.

## User Story

As a shopper browsing products, I want a way to request a custom quote when I can't find exactly what I need, so I can still do business with Afida rather than leaving the site.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Click action | Link to `/contact` | Simple, no new forms to build or maintain |
| Placement | Product pages only | Contextual, appears at the decision point |
| Context passing | None | Keep it simple, shopper explains their needs |
| Copy style | Brandyour.co pattern | Proven, addresses moment of frustration |

## Visual Design

### Copy
- **Headline**: "Can't find what you're looking for?"
- **Subtext**: "Need a different size, quantity, or material?"
- **Link**: "Get in touch" → `/contact`

### Placement
Below the quantity selector, above the delivery info section in the product purchase zone. This positions it after shoppers have seen available options but before they commit to purchase.

### Styling
Subtle card with light grey background. No heavy borders - should feel helpful, not pushy. Match existing site aesthetic using TailwindCSS/DaisyUI utilities.

Reference (Brandyour.co):
```
┌─────────────────────────────────────────────────────────┐
│  Can't find what you're looking for?                    │
│  Need a different size, quantity or finish...           │
│                                            Click here.  │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### Files to Create
- `app/views/products/_quote_request_cta.html.erb` - The CTA partial

### Files to Modify
- `app/views/products/_standard_product.html.erb` - Render the CTA after quantity select (around line 190, before delivery info section)

### No Changes Needed
- No new routes
- No new controllers
- No JavaScript
- No database changes
- No new Stimulus controllers

## Testing

Manual verification:
1. Visit any product page
2. Verify CTA appears below quantity selector
3. Click "Get in touch" link
4. Verify navigation to `/contact` page
