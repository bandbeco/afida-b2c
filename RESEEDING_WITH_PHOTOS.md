# Reseeding Database While Preserving Photos

This guide explains two approaches for reseeding your database with product photos.

## Important Discovery

**❌ Signed IDs Don't Survive `db:reset`**

When `rails db:reset` runs:
- ✅ Photo files remain in `storage/` directory
- ❌ **BUT** the `active_storage_blobs` table is dropped
- ❌ Blob metadata records are deleted
- ❌ Signed IDs become invalid (they reference database records by ID)

**Result:** You cannot preserve photos through a full `db:reset` using signed IDs alone.

## Two Approaches

### Approach 1: Full Reset with Photo Re-upload (Works ✅)

**Best for:** Development, when you have the original photo files

**How it works:**
1. Photo files exist in `lib/data/products/photos/raw/`
2. Run `rails db:reset` (completely wipes database)
3. Seed automatically re-uploads photos from files
4. New Active Storage blobs are created

**Workflow:**
```bash
# Ensure attachment_mapping.json doesn't exist (so it falls back to files)
rm -f attachment_mapping.json

# Reset database (photos will be re-uploaded from files)
rails db:reset
```

**Requirements:**
- Photo files must exist in `lib/data/products/photos/raw/`
- Files must be named by SKU (e.g., `12BRDW.webp` for SKU "12BRDW")

**Result:** Fresh database with newly uploaded photos (✅ Tested and working)

---

### Approach 2: Partial Reset Preserving Active Storage (Works ✅)

**Best for:** Production, when re-uploading is expensive/slow

**How it works:**
1. Keep `active_storage_blobs` and `active_storage_attachments` tables intact
2. Delete only product-related tables
3. Reseed products
4. Reattach using signed IDs from CSV

**Workflow:**
```bash
# Add photo signed IDs to CSV first
rails csv:add_photos

# Partial reset (preserves Active Storage tables)
rails db:drop db:create db:migrate

# Delete only product data (keeps Active Storage intact)
rails runner "
  [Category, Product, ProductVariant, Cart, CartItem, Order, OrderItem].each do |model|
    model.delete_all
  end
"

# Seed products (will reattach photos using signed IDs from CSV)
rails db:seed
```

**Requirements:**
- `lib/data/products.csv` must have photo signed ID columns
- Active Storage tables must remain intact

**Result:** Reseeded products with same photos (no re-upload)

## Current Status ✅

**What's implemented:**
- ✅ File-based photo upload works perfectly with `rails db:reset`
- ✅ CSV has photo signed ID columns (for Approach 2)
- ✅ Automatic fallback from signed IDs → files
- ✅ 51 photo files in `lib/data/products/photos/raw/`
- ✅ Successfully tested: 24 products with photos, 46 variants with photos

**Tested workflow (Approach 1):**

```bash
# 1. Remove JSON mapping to force file-based upload
rm -f attachment_mapping.json

# 2. Reset database (photos re-uploaded from files)
rails db:reset
```

**Seed output:**
```
Checking for any missing product photos...
  No photos found. Attempting fallback methods...
  ⚠ attachment_mapping.json not found!
  Falling back to file-based photo attachment...
  Found 51 photo files
  ✓ Attached 12BRDW.webp to Ripple Wall Hot Cups (product) and 12BRDW (variant)
  ...
Product photos attached successfully (from files)!
  Photos attached: 46
  Products with photos: 24
  Variants with photos: 46
```

**Result:** ✅ All photos successfully re-uploaded and attached

## Files Created/Modified

- `lib/data/products.csv` - Updated with photo signed ID columns
- `lib/tasks/add_photos_to_csv.rake` - Task to add photo data to CSV
- `db/seeds/products_from_csv.rb` - Updated to attach photos during product creation
- `db/seeds/product_photos.rb` - Updated to skip if photos already attached from CSV
- `lib/tasks/export_attachments.rake` - Export task (legacy fallback)
- `lib/tasks/test_attachments.rake` - Test task
- `lib/tasks/export_photos.rake` - Export photo URLs to CSV
- `attachment_mapping.json` - Photo attachment mapping (in project root, optional)

## Important Notes

### Active Storage Blob Storage

- Blobs are stored separately from database records
- `db:reset` destroys attachment *records* but not the *blob files*
- Blob files remain in `storage/` (development) or S3 (production)
- Signed IDs reconnect records to existing blobs without re-uploading

### Signed ID Expiration

Active Storage signed IDs **do not expire** by default. They remain valid as long as:
1. The blob file exists in storage
2. Rails' `secret_key_base` hasn't changed

### When to Re-export

You need to re-export the attachment mapping if:
- You add new photos to products/variants
- You change product slugs or variant SKUs
- You want to capture the latest attachment state

### Fallback Behavior

If `attachment_mapping.json` is not found, the seed file automatically falls back to:
- Reading photo files from `lib/data/products/photos/raw/`
- Uploading them as new Active Storage blobs
- Attaching them to products/variants by SKU

This ensures the seed process works even without the mapping file.

## Rake Tasks Reference

```bash
# Add photo attachment data to products.csv (recommended)
rails csv:add_photos

# Export attachment mapping to JSON (legacy fallback)
rails attachments:export

# Test signed ID validity
rails attachments:test

# Export photo URLs to CSV
rails photos:export
```

## Production Workflow

For production reseeding:

1. **On production server**, run:
   ```bash
   rails attachments:export
   ```

2. **Download** `attachment_mapping.json` to your local machine

3. **Backup** the production database (important!)

4. Run `rails db:reset` on production

5. Photos will be reattached from the mapping file

## Development Workflow

For local development reseeding:

1. Export attachments: `rails attachments:export`
2. Reset database: `rails db:reset`
3. Photos automatically reattach during seed

## Troubleshooting

### "Blob not found" errors during seed

- Signed IDs might be invalid (Rails secret changed)
- Blob files might be deleted from storage
- Re-run `rails attachments:export` to get fresh signed IDs

### Photos not appearing after seed

- Check seed output for error messages
- Verify `attachment_mapping.json` exists
- Run `rails attachments:test` to validate signed IDs
- Check that product slugs and variant SKUs match the mapping file

### Mapping file shows "null" for all photos

- Products/variants don't have photos attached
- Run the original photo attachment process first
- Check that `lib/data/products/photos/raw/` contains photo files
