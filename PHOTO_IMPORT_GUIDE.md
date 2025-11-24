# Photo Import Guide

## Overview

The `rake products:import` task now automatically attaches photos when importing products from CSV.

## How It Works

### Photo Directories

- **Raw Photos**: `lib/data/products/photos/raw/`
  - Attached as `product_photo` (close-up product shots)
  - 76 photos available

- **Lifestyle Photos**: `lib/data/products/photos/lifestyle/`
  - Attached as `lifestyle_photo` (product in context)
  - 27 photos available

### Photo Matching

Photos are matched by **SKU** (case-sensitive):

```
SKU: 12BRDW
├── raw/12BRDW.png       → attached as product_photo
└── lifestyle/12BRDW.jpg → attached as lifestyle_photo
```

### Supported Extensions

The task automatically detects photos with these extensions:
- `.jpg`
- `.jpeg`
- `.png`
- `.webp`

### Attachment Strategy

When a photo is found for a SKU:
1. **Variant**: Photo is attached to the ProductVariant
2. **Product**: Photo is also attached to parent Product (if not already attached)

This ensures:
- Product listing pages can show photos even without selecting a variant
- Individual variants can have their own photos
- First variant's photos become the product's default photos

## Usage

### Import Products with Photos

```bash
rails products:import
```

Output example:
```
Created product: Ripple Wall Hot Cups (ripple-wall-hot-cups)
  Created variant: 12oz (12BRDW)
    📸 Attached product photo: 12BRDW.png
    📸 Attached lifestyle photo: 12BRDW.jpg
  Created variant: 8oz (8BRDW)
    📸 Attached product photo: 8BRDW.png
```

### Summary Statistics

At the end of import, you'll see:
```
============================================================
Import completed!
============================================================
Products created: 24
Products updated: 0
Variants created: 78
Variants updated: 0
Categories created: 8
Options created: 3
Product photos attached: 46
Lifestyle photos attached: 27
============================================================
```

## Photo Coverage Examples

### Full Coverage (both raw + lifestyle)
- **12BRDW**: raw/12BRDW.png + lifestyle/12BRDW.jpg
- **8KRDW**: raw/8KRDW.jpg + lifestyle/8KRDW.jpg
- **12PIZBKR**: raw/12PIZBKR.png + lifestyle/12PIZBKR.jpg
- **5MLREC**: raw/5MLREC.png + lifestyle/5MLREC.jpg
- **BB-BOX-NAP**: raw/BB-BOX-NAP.png + lifestyle/BB-BOX-NAP.jpg

### Partial Coverage (raw only)
Some SKUs only have raw photos (no lifestyle photo):
- **PLPC90B**: raw/PLPC90B.png (no lifestyle)
- **16WSW**: raw/16WSW.png (no lifestyle)
- **NO3KDV**: raw/NO3KDV.png (no lifestyle)

This is fine - the system handles missing photos gracefully.

## Adding New Photos

To add photos for a new product:

1. Add raw photo: `lib/data/products/photos/raw/SKU.png`
2. Add lifestyle photo (optional): `lib/data/products/photos/lifestyle/SKU.jpg`
3. Run import: `rails products:import`

The photos will be automatically attached!

## Technical Details

### Helper Methods Added

1. **`attach_photos_for_sku(variant, product, sku, stats)`**
   - Main method called after each variant is saved
   - Looks for photos in both directories
   - Attaches to variant and parent product

2. **`find_photo_by_sku(directory, sku)`**
   - Searches for photo file matching SKU
   - Tries all supported extensions
   - Returns first match or nil

3. **`attach_photo(model, attachment_name, photo_path)`**
   - Attaches photo to Active Storage
   - Determines correct MIME type
   - Handles file I/O

### Photo Deduplication

Photos are only attached if not already present:
```ruby
if raw_photo_path && !variant.product_photo.attached?
  attach_photo(variant, :product_photo, raw_photo_path)
end
```

This prevents:
- Duplicate uploads on re-import
- Overwriting existing photos
- Unnecessary storage usage

## Troubleshooting

### Photos not attaching?

Check that:
1. Photo file exists in correct directory
2. Filename exactly matches SKU (case-sensitive)
3. Extension is one of: .jpg, .jpeg, .png, .webp
4. File is readable (permissions)

### Wrong photo attached?

The task attaches the **first matching photo** it finds:
1. Checks `.jpg`
2. Then `.jpeg`
3. Then `.png`
4. Finally `.webp`

If multiple files exist for one SKU, only the first is used.
