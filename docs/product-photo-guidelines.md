# Product Photo Guidelines

Guidelines for preparing product photos before upload to ensure consistent, professional presentation across the site.

## How Photos Are Displayed

Product photos are transformed using `resize_and_pad` which:
1. Resizes the image to fit within target dimensions (preserving aspect ratio)
2. Adds white padding to create exact square dimensions
3. Centers the image within the padded area

This means the **entire source image is preserved** - the system won't automatically crop out empty space or reframe the product.

## Recommended Specifications

### Dimensions
| Requirement | Specification |
|-------------|---------------|
| Minimum size | 800 x 800 pixels |
| Recommended size | 1200 x 1200 pixels |
| Maximum size | 2400 x 2400 pixels |
| Aspect ratio | Square (1:1) preferred |

### File Format
- **Preferred:** WebP (best compression, quality)
- **Acceptable:** JPEG, PNG
- **For transparency:** PNG only (transparent areas fill with white)

### File Size
- Target: Under 500KB after compression
- Maximum: 2MB

## Composition Guidelines

### Product Framing

**DO:**
- Center the product in the frame
- Fill 70-85% of the frame with the product
- Leave small, even margins on all sides
- Shoot against a plain white or light grey background

**DON'T:**
- Leave excessive empty space above/below/around the product
- Position the product in a corner or edge
- Include multiple products in a single photo (unless it's a kit)
- Use busy or coloured backgrounds

### Examples

**Good composition:**
```
┌─────────────────┐
│     margin      │
│  ┌───────────┐  │
│  │           │  │
│  │  PRODUCT  │  │
│  │           │  │
│  └───────────┘  │
│     margin      │
└─────────────────┘
Product fills ~80% of frame, centered with even margins
```

**Bad composition:**
```
┌─────────────────┐
│                 │
│                 │
│                 │
│    empty space  │
│                 │
│  ┌─────┐        │
│  │PROD │        │
└──┴─────┴────────┘
Product small, off-center, excessive empty space
```

### Aspect Ratio Handling

| Source Aspect | Result |
|---------------|--------|
| Square (1:1) | No padding added |
| Portrait (tall) | White padding added left/right |
| Landscape (wide) | White padding added top/bottom |

For non-square images, crop before upload to avoid excessive padding.

## Pre-Upload Checklist

Before uploading a product photo:

- [ ] Image is at least 800x800 pixels
- [ ] Product is centered in the frame
- [ ] Product fills 70-85% of the frame
- [ ] Background is white or very light grey
- [ ] No excessive empty space on any side
- [ ] File size is under 2MB
- [ ] File format is WebP, JPEG, or PNG

## Quick Cropping Guide

### macOS Preview
1. Open image in Preview
2. Press `Cmd + K` to show crop tool
3. Drag selection around product with small margins
4. Press `Cmd + K` to crop
5. Save

### macOS Photos
1. Double-click image to edit
2. Click "Crop" in toolbar
3. Select "Square" aspect ratio
4. Drag to frame product
5. Click "Done"

### Online Tools
- [Squoosh](https://squoosh.app) - Crop, resize, and compress
- [Remove.bg](https://remove.bg) - Remove backgrounds (if needed)

## Photo Types

### Product Photo
- Clean, straight-on product shot
- White background
- Shows product clearly for purchase decisions
- Used as primary image on cards and detail pages

### Lifestyle Photo
- Product in use or styled setting
- Shows scale, context, or use case
- Appears on hover (product cards) or in gallery
- Can have environmental background

## Troubleshooting

### "Product appears too small on the page"
The source image has too much empty space. Crop the image to frame the product more tightly.

### "Product is cut off on mobile"
Source image is extremely wide or tall. Crop to a more square aspect ratio.

### "Background colour doesn't match site"
Source image has non-white background. Either:
- Re-shoot against white background
- Use background removal tool
- Accept the existing background colour

### "Image looks blurry"
Source image resolution is too low. Use minimum 800x800px, ideally 1200x1200px.
