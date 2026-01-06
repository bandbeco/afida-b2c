# Attach branded product photos from folder structure:
# lib/data/branded/photos/{product-slug}/
#   - main.webp → placeholder variant.product_photo
#   - lifestyle.webp → placeholder variant.lifestyle_photo
#
# Photos are attached to the placeholder variant only.
# Views should use variant.primary_photo (or product.variants.first.primary_photo).
#
puts 'Attaching branded product photos...'

photo_base_dir = Rails.root.join('lib', 'data', 'branded', 'photos')

unless Dir.exist?(photo_base_dir)
  puts "  ⚠ Branded photos directory not found at #{photo_base_dir}"
  return
end

# Get all product slug folders
product_dirs = Dir.glob(photo_base_dir.join('*')).select { |f| File.directory?(f) }

if product_dirs.empty?
  puts "  ⚠ No branded product folders found in #{photo_base_dir}"
  return
end

puts "  Found #{product_dirs.count} branded product folders"

stats = {
  products_found: 0,
  products_not_found: 0,
  product_photos_attached: 0,
  lifestyle_photos_attached: 0,
  skipped: 0
}

def content_type_for_branded(filename)
  case File.extname(filename).downcase
  when '.webp' then 'image/webp'
  when '.png' then 'image/png'
  when '.jpg', '.jpeg' then 'image/jpeg'
  else 'application/octet-stream'
  end
end

def attach_branded_photo(record, attachment_name, photo_path, stats_key, stats)
  return if record.send(attachment_name).attached?

  filename = File.basename(photo_path)
  record.send(attachment_name).attach(
    io: File.open(photo_path),
    filename: filename,
    content_type: content_type_for_branded(filename)
  )
  stats[stats_key] += 1
  true
end

product_dirs.each do |product_dir|
  slug = File.basename(product_dir)

  # Find branded product (customizable_template type)
  product = Product.find_by(slug: slug, product_type: 'customizable_template')

  unless product
    stats[:products_not_found] += 1
    puts "  ⚠ No branded product found for slug: #{slug}"
    next
  end

  stats[:products_found] += 1

  # Find the placeholder variant for this branded product
  variant = product.variants.first
  unless variant
    puts "  ⚠ #{slug}: no placeholder variant found"
    next
  end

  # Attach main.webp as product_photo to the placeholder variant
  main_photo = Dir.glob(File.join(product_dir, 'main.{webp,png,jpg,jpeg}')).first
  if main_photo
    if attach_branded_photo(variant, :product_photo, main_photo, :product_photos_attached, stats)
      puts "  ✓ #{slug}: attached main photo"
    end
  end

  # Attach lifestyle.webp as lifestyle_photo to the placeholder variant
  lifestyle_photo = Dir.glob(File.join(product_dir, 'lifestyle.{webp,png,jpg,jpeg}')).first
  if lifestyle_photo
    if attach_branded_photo(variant, :lifestyle_photo, lifestyle_photo, :lifestyle_photos_attached, stats)
      puts "  ✓ #{slug}: attached lifestyle photo"
    end
  end
end

puts ''
puts 'Branded product photos attached successfully!'
puts "  Product folders processed: #{stats[:products_found]}"
puts "  Product folders not found: #{stats[:products_not_found]}"
puts "  Product photos attached: #{stats[:product_photos_attached]}"
puts "  Lifestyle photos attached: #{stats[:lifestyle_photos_attached]}"
branded_variants = ProductVariant.joins(:product).where(products: { product_type: 'customizable_template' })
puts "  Placeholder variants with product_photo: #{branded_variants.joins(:product_photo_attachment).count}"
puts "  Placeholder variants with lifestyle_photo: #{branded_variants.joins(:lifestyle_photo_attachment).count}"
