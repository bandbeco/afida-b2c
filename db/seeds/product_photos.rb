# Attach product photos from flat folder structure:
# lib/data/products/photos/{SKU}.webp → product with matching SKU gets product_photo
#
puts 'Attaching product photos...'

photo_base_dir = Rails.root.join('lib', 'data', 'products', 'photos')

unless Dir.exist?(photo_base_dir)
  puts "  ⚠ Photos directory not found at #{photo_base_dir}"
  return
end

stats = {
  product_photos_attached: 0,
  products_not_found: 0
}

def content_type_for_photo(filename)
  case File.extname(filename).downcase
  when '.webp' then 'image/webp'
  when '.png' then 'image/png'
  when '.jpg', '.jpeg' then 'image/jpeg'
  else 'application/octet-stream'
  end
end

def attach_product_photo(record, photo_path, stats)
  return if record.product_photo.attached?

  filename = File.basename(photo_path)
  record.product_photo.attach(
    io: File.open(photo_path),
    filename: filename,
    content_type: content_type_for_photo(filename)
  )
  stats[:product_photos_attached] += 1
  true
end

# Get all photo files in the flat directory
photo_files = Dir.glob(photo_base_dir.join('*.{webp,png,jpg,jpeg}'))

if photo_files.empty?
  puts "  ⚠ No photo files found in #{photo_base_dir}"
  return
end

puts "  Found #{photo_files.count} photo files"

photo_files.each do |photo_path|
  filename = File.basename(photo_path)
  sku = File.basename(filename, File.extname(filename))

  # Find product by SKU (case-insensitive match)
  product = Product.find_by('UPPER(sku) = ?', sku.upcase)

  unless product
    stats[:products_not_found] += 1
    puts "  ⚠ No product found for SKU: #{sku}"
    next
  end

  if attach_product_photo(product, photo_path, stats)
    puts "  ✓ #{sku}: attached photo"
  end
end

puts ''
puts 'Product photos attached successfully!'
puts "  Photos processed: #{photo_files.count}"
puts "  Product photos attached: #{stats[:product_photos_attached]}"
puts "  Product SKUs not found: #{stats[:products_not_found]}"
puts "  Products with product_photo: #{Product.joins(:product_photo_attachment).distinct.count}"
