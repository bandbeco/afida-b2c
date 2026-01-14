# Search Results Redesign

## Problem

The global search modal displays product cards with truncated, identical titles for products in the same family. For example, searching "ice" shows 5 Ice Cream Cups all displaying "Ice Cream Cups (Ice..." – providing no differentiation for users to identify which specific product they want.

## Solution

Replace the grid layout with a horizontal list layout that prioritizes differentiating information.

## Design

### Layout

Horizontal stacked rows (list view) replacing the current 5-column grid:

```
┌────────────────────────────────────────────────────────────────────┐
│ [img]  8oz Rainbow                                                 │
│        Ice Cream Cups · Pack of 500                        £20.99  │
├────────────────────────────────────────────────────────────────────┤
│ [img]  12oz Pink Stripe                                            │
│        Ice Cream Cups · Pack of 500                        £21.99  │
├────────────────────────────────────────────────────────────────────┤
│ [img]  16oz Blue Swirl                                             │
│        Ice Cream Cups · Pack of 300                        £27.93  │
└────────────────────────────────────────────────────────────────────┘
```

### Row Structure

- **Thumbnail**: Left-aligned, ~60px square, product photo
- **Line 1** (bold): Differentiator text (size + colour for family products, product name for standalone)
- **Line 2** (gray): Context text (family name or category) + pack size when applicable
- **Price**: Right-aligned, primary color

### Display Logic

| Product Type | Line 1 (Primary) | Line 2 (Secondary) |
|--------------|------------------|-------------------|
| In a product family | Size + Colour (e.g., "8oz Rainbow") | Family name · Pack of X |
| Standalone product | Product name | Category name · Pack of X |

Pack size shown only when `pac_size > 1`.

## Benefits

1. **No truncation** – Horizontal rows provide full width for text
2. **Faster scanning** – Eyes move down single column vs zigzagging across grid
3. **Better differentiation** – Text is primary, images secondary (important when products look similar)
4. **Mobile-friendly** – Same layout works on all screen sizes

## Implementation

### Files to Modify

- `app/views/search/_modal_results.html.erb` – Replace grid with list layout

### New Helper Method

Add to Product model:

```ruby
# Returns the differentiating text for search results
# For family products: combines size and colour
# For standalone: returns the product name
def search_display_title
  if product_family.present?
    [size, colour].compact_blank.join(" ").presence || name
  else
    name
  end
end

# Returns the contextual subtitle for search results
def search_display_subtitle
  if product_family.present?
    product_family.name
  else
    category&.name
  end
end
```

### Pack Size Display

Use existing `pac_size` attribute. Display as "Pack of X" when `pac_size > 1`.
