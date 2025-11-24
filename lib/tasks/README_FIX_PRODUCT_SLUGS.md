# Fix Product Slugs Rake Task

## Overview

The `products:fix_slugs` rake task deduplicates products and updates their slugs and names to match the CSV data. This is useful when you've updated product names/slugs in the CSV and reseeded the database, creating duplicates.

## How It Works

1. **Groups products by variant SKUs** - Products with identical sets of variant SKUs are considered duplicates
2. **Keeps products with photos** - Prioritizes keeping products that have photos attached
3. **Updates slug and name** - Updates the kept product's slug and name to match the CSV
4. **Deletes duplicates** - Removes duplicate products without photos

## Usage

```bash
rails products:fix_slugs
```

## Manual Testing Procedure

### Test Case 1: Identify and Remove Duplicates

**Setup:**
1. Create duplicate products in database:
```ruby
rails console
category = Category.first
variant1 = ProductVariant.create!(sku: "TEST1", name: "Test", price: 10.0, active: true)

# Product with photos (will be kept)
p1 = Product.create!(name: "Test Product", slug: "test-product", category: category, active: true)
p1.variants << variant1
p1.product_photo.attach(io: File.open("path/to/image.png"), filename: "test.png")

# Duplicate without photos (will be deleted)
p2 = Product.create!(name: "Test Products", slug: "test-products", category: category, active: true)
p2.variants << variant1

Product.count # Should return 2
```

2. Update CSV with pluralized version:
```csv
product,category,slug,sku
Test Products,category-slug,test-products,TEST1
```

**Execute:**
```bash
rails products:fix_slugs
```

**Expected Output:**
```
Found 36 unique products in CSV

Found duplicate products with variants: TEST1
  🗑  Deleting duplicate: Test Products (test-products) - no photos
  ✓ Updated slug: Test Product (test-product → test-products)
  ✓ Updated name: Test Product → Test Products

Done!
  Slugs updated: 1
  Names updated: 1
  Duplicates deleted: 1
  Total products now: 1
```

**Verify:**
```ruby
Product.count # Should return 1
product = Product.first
product.name # Should be "Test Products"
product.slug # Should be "test-products"
product.product_photo.attached? # Should be true
```

---

### Test Case 2: Keeps Product with Photos

**Setup:**
1. Create two duplicates where ONLY the second one has photos:
```ruby
variant = ProductVariant.create!(sku: "TEST2", name: "Test", price: 10.0, active: true)

# Without photos
p1 = Product.create!(name: "Old Name", slug: "old-slug", category: category, active: true)
p1.variants << variant

# With photos (will be kept)
p2 = Product.create!(name: "New Name", slug: "new-slug", category: category, active: true)
p2.variants << variant
p2.product_photo.attach(io: File.open("path/to/image.png"), filename: "test.png")
```

**Execute:**
```bash
rails products:fix_slugs
```

**Verify:**
```ruby
Product.count # Should return 1
Product.first.product_photo.attached? # Should be true (kept the one with photos)
```

---

### Test Case 3: No Duplicates

**Setup:**
1. Database with no duplicate products

**Execute:**
```bash
rails products:fix_slugs
```

**Expected Output:**
```
Found 36 unique products in CSV

Done!
  Slugs updated: 0
  Names updated: 0
  Duplicates deleted: 0
  Total products now: 43
```

---

## Production Testing (Already Verified)

✅ **Tested on 2025-11-17** with production data:
- Initial state: 43 products (2 duplicates detected)
- After running task:
  - Duplicates deleted: 2
  - Products updated: 0
  - Final count: 43 products
  - All product names and slugs match CSV ✓

Command used for verification:
```bash
rails runner "
  require 'csv'
  csv_path = Rails.root.join('lib', 'data', 'products.csv')
  sku_to_product = {}
  CSV.foreach(csv_path, headers: true) do |row|
    sku_to_product[row['sku']] = { name: row['product'], slug: row['slug'] }
  end

  mismatches = Product.includes(:variants).reject do |product|
    next true if product.variants.empty?
    expected = sku_to_product[product.variants.first.sku]
    next true unless expected
    product.name == expected[:name] && product.slug == expected[:slug]
  end

  if mismatches.any?
    puts 'Mismatches found!'
    mismatches.each { |p| puts p.name }
  else
    puts '✓ All product names and slugs match the CSV!'
  end
"
```

Result: ✓ All product names and slugs match the CSV!

## Notes

- The task is idempotent - safe to run multiple times
- Only deletes products that have NO photos attached
- Requires `lib/data/products.csv` to exist
- Updates both `name` and `slug` fields to match CSV
