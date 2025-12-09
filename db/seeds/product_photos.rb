# Attach product photos from folder structure:
# lib/data/products/photos/{product-slug}/
#   - main.webp → product.product_photo
#   - lifestyle.webp → product.lifestyle_photo
#   - {SKU}.webp → variant.product_photo
#
puts 'Attaching product photos...'

photo_base_dir = Rails.root.join('lib', 'data', 'products', 'photos')

unless Dir.exist?(photo_base_dir)
  puts "  ⚠ Photos directory not found at #{photo_base_dir}"
  return
end

# Get all product slug folders
product_dirs = Dir.glob(photo_base_dir.join('*')).select { |f| File.directory?(f) }

if product_dirs.empty?
  puts "  ⚠ No product folders found in #{photo_base_dir}"
  return
end

puts "  Found #{product_dirs.count} product folders"

stats = {
  products_found: 0,
  products_not_found: 0,
  product_photos_attached: 0,
  lifestyle_photos_attached: 0,
  variant_photos_attached: 0,
  variants_not_found: 0,
  skipped: 0
}

def content_type_for(filename)
  case File.extname(filename).downcase
  when '.webp' then 'image/webp'
  when '.png' then 'image/png'
  when '.jpg', '.jpeg' then 'image/jpeg'
  else 'application/octet-stream'
  end
end

def attach_photo(record, attachment_name, photo_path, stats_key, stats)
  return if record.send(attachment_name).attached?

  filename = File.basename(photo_path)
  record.send(attachment_name).attach(
    io: File.open(photo_path),
    filename: filename,
    content_type: content_type_for(filename)
  )
  stats[stats_key] += 1
  true
end

product_dirs.each do |product_dir|
  slug = File.basename(product_dir)
  product = Product.find_by(slug: slug)

  unless product
    stats[:products_not_found] += 1
    puts "  ⚠ No product found for slug: #{slug}"
    next
  end

  stats[:products_found] += 1

  # Attach main.webp as product_photo
  main_photo = Dir.glob(File.join(product_dir, 'main.{webp,png,jpg,jpeg}')).first
  if main_photo
    if attach_photo(product, :product_photo, main_photo, :product_photos_attached, stats)
      puts "  ✓ #{slug}: attached main photo"
    end
  end

  # Attach lifestyle.webp as lifestyle_photo
  lifestyle_photo = Dir.glob(File.join(product_dir, 'lifestyle.{webp,png,jpg,jpeg}')).first
  if lifestyle_photo
    if attach_photo(product, :lifestyle_photo, lifestyle_photo, :lifestyle_photos_attached, stats)
      puts "  ✓ #{slug}: attached lifestyle photo"
    end
  end

  # Attach SKU-named files to variants
  photo_files = Dir.glob(File.join(product_dir, '*.{webp,png,jpg,jpeg}'))
  photo_files.each do |photo_path|
    filename = File.basename(photo_path)
    basename = File.basename(filename, File.extname(filename))

    # Skip main and lifestyle photos (already handled)
    next if %w[main lifestyle].include?(basename.downcase)

    # Find variant by SKU
    variant = product.variants.find_by(sku: basename)

    unless variant
      stats[:variants_not_found] += 1
      puts "  ⚠ #{slug}: no variant found for SKU: #{basename}"
      next
    end

    if attach_photo(variant, :product_photo, photo_path, :variant_photos_attached, stats)
      puts "  ✓ #{slug}: attached #{basename} to variant"
    end
  end
end

puts ''
puts 'Product photos attached successfully!'
puts "  Product folders processed: #{stats[:products_found]}"
puts "  Product folders not found: #{stats[:products_not_found]}"
puts "  Product photos attached: #{stats[:product_photos_attached]}"
puts "  Lifestyle photos attached: #{stats[:lifestyle_photos_attached]}"
puts "  Variant photos attached: #{stats[:variant_photos_attached]}"
puts "  Variant SKUs not found: #{stats[:variants_not_found]}"
puts "  Products with product_photo: #{Product.joins(:product_photo_attachment).distinct.count}"
puts "  Products with lifestyle_photo: #{Product.joins(:lifestyle_photo_attachment).distinct.count}"
puts "  Variants with photos: #{ProductVariant.joins(:product_photo_attachment).distinct.count}"
