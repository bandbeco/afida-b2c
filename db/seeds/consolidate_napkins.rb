# Consolidate napkin products into 3 use-case-based products:
# - Cocktail Napkins (4 variants)
# - Dinner Napkins (7 variants)
# - Dispenser Napkins (1 variant)
#
# This script MOVES existing variants to new consolidated products.
# It does not create duplicate SKUs.

puts "Consolidating napkin products..."

napkins_category = Category.find_by!(slug: 'napkins')
photos_base = Rails.root.join('lib/data/products/photos')

# Helper to attach a photo to a model if the file exists
def attach_photo(model, attachment_name, photo_path)
  return unless File.exist?(photo_path)

  model.public_send(attachment_name).attach(
    io: File.open(photo_path),
    filename: File.basename(photo_path),
    content_type: 'image/webp'
  )
end

# Helper to move a variant from old product to new product
def move_variant_to_product(sku:, new_product:, name:, material:, colour:, price:, pac_size:, active: true)
  # Find existing variant anywhere in database
  variant = ProductVariant.find_by(sku: sku)

  if variant
    # Move to new product and update attributes
    variant.update!(
      product: new_product,
      name: name,
      price: price,
      pac_size: pac_size,
      stock_quantity: 10000,
      active: active,
      sample_eligible: true,
      option_values: { 'material' => material, 'colour' => colour }
    )
    puts "    Moved #{sku} to #{new_product.slug}"
  else
    # Create new variant if doesn't exist
    new_product.variants.create!(
      sku: sku,
      name: name,
      price: price,
      pac_size: pac_size,
      stock_quantity: 10000,
      active: active,
      sample_eligible: true,
      option_values: { 'material' => material, 'colour' => colour }
    )
    puts "    Created #{sku} on #{new_product.slug}"
  end
end

# =============================================================================
# 1. COCKTAIL NAPKINS
# =============================================================================
cocktail_napkins = Product.unscoped.find_or_initialize_by(slug: 'cocktail-napkins')
cocktail_napkins.assign_attributes(
  name: 'Cocktail Napkins',
  category: napkins_category,
  product_type: 'standard',
  active: true,
  description_short: 'Quality cocktail napkins in paper, airlaid, and bamboo options for any occasion.',
  description_standard: 'Premium cocktail napkins perfect for bars, restaurants, and events. Choose from budget-friendly paper, soft airlaid, or eco-friendly bamboo materials. All sizes 23-25cm for versatile cocktail service.',
  description_detailed: 'Our cocktail napkin range offers the right material for every venue and budget. Paper napkins provide excellent value for high-volume service. Airlaid napkins deliver a soft, cloth-like feel that impresses guests. Bamboo napkins offer 100% compostable sustainability for eco-conscious establishments. All napkins are sized 23-25cm, perfect for cocktail service, canape presentation, and table settings. Available in white, black, and natural colours to complement any decor.',
  meta_title: 'Cocktail Napkins | Paper, Airlaid & Bamboo | Afida',
  meta_description: 'Premium cocktail napkins (23-25cm) in paper, airlaid, and bamboo. Perfect for bars and restaurants. Bulk pricing with free UK delivery over £100.'
)
cocktail_napkins.save!

# Attach product photo
unless cocktail_napkins.product_photo.attached?
  attach_photo(cocktail_napkins, :product_photo, photos_base.join('paper-cocktail-napkins/main.webp'))
end

puts "  Creating Cocktail Napkins..."
# Cocktail napkin variants
cocktail_variants = [
  { sku: 'PCNWH', material: 'Paper', colour: 'white', price: 28.79, pac_size: 2000, name: 'Paper White', active: true },
  { sku: 'PCNBL', material: 'Paper', colour: 'black', price: 28.79, pac_size: 2000, name: 'Paper Black', active: true },
  { sku: 'AIRCNWH', material: 'Airlaid', colour: 'white', price: 78.59, pac_size: 2400, name: 'Airlaid White', active: true },
  { sku: 'BB-BOX-NAP', material: 'Bamboo', colour: 'natural', price: 40.80, pac_size: 2400, name: 'Bamboo Natural', active: true }
]

cocktail_variants.each do |v|
  move_variant_to_product(new_product: cocktail_napkins, **v)
end

# Attach variant photos
cocktail_variant_photos = {
  'PCNWH' => photos_base.join('paper-cocktail-napkins/PCNWH.webp'),
  'PCNBL' => photos_base.join('paper-cocktail-napkins/PCNBL.webp'),
  'AIRCNWH' => photos_base.join('airlaid-cocktail-napkins/AIRCNWH.webp'),
  'BB-BOX-NAP' => photos_base.join('bamboo-cocktail-napkins/BB-BOX-NAP.webp')
}
cocktail_variant_photos.each do |sku, photo_path|
  variant = ProductVariant.find_by(sku: sku)
  next unless variant && !variant.product_photo.attached?
  attach_photo(variant, :product_photo, photo_path)
end

puts "  ✓ Cocktail Napkins: #{cocktail_napkins.variants.reload.count} variants"

# =============================================================================
# 2. DINNER NAPKINS
# =============================================================================
dinner_napkins = Product.unscoped.find_or_initialize_by(slug: 'dinner-napkins')
dinner_napkins.assign_attributes(
  name: 'Dinner Napkins',
  category: napkins_category,
  product_type: 'standard',
  active: true,
  description_short: 'Premium 40cm dinner napkins from budget paper to luxury airlaid with pocket option.',
  description_standard: 'Large 40cm dinner napkins for formal dining and events. Choose from 2-ply paper, 3-ply premium, soft airlaid, or luxury pocket napkins with built-in cutlery holder. White and black options available.',
  description_detailed: 'Our dinner napkin collection covers every quality tier for 40cm table napkins. Paper 2-ply offers excellent value for everyday dining. Paper 3-ply delivers enhanced softness and absorbency. Airlaid napkins provide a luxurious cloth-like feel that rivals linen. Airlaid pocket napkins feature an elegant built-in cutlery holder for streamlined table service. All dinner napkins are 40x40cm in the classic 4-fold or 8-fold presentation. Perfect for restaurants, hotels, wedding venues, and catering services.',
  meta_title: 'Dinner Napkins 40cm | Paper & Airlaid | Afida',
  meta_description: 'Premium 40cm dinner napkins in paper 2-ply, 3-ply, airlaid, and pocket styles. White and black. Bulk pricing with free UK delivery over £100.'
)
dinner_napkins.save!

# Attach product photo
unless dinner_napkins.product_photo.attached?
  attach_photo(dinner_napkins, :product_photo, photos_base.join('premium-dinner-napkins/main.webp'))
end

puts "  Creating Dinner Napkins..."
# Dinner napkin variants
dinner_variants = [
  { sku: '4FDINWH', material: 'Paper 2-ply', colour: 'white', price: 51.76, pac_size: 2000, name: 'Paper 2-ply White', active: true },
  { sku: '4FDINBL', material: 'Paper 2-ply', colour: 'black', price: 68.21, pac_size: 2000, name: 'Paper 2-ply Black', active: true },
  { sku: '8FDINWH', material: 'Paper 3-ply', colour: 'white', price: 53.82, pac_size: 2000, name: 'Paper 3-ply White', active: true },
  { sku: '8FDINBL', material: 'Paper 3-ply', colour: 'black', price: 53.82, pac_size: 2000, name: 'Paper 3-ply Black', active: true },
  { sku: '8FAIRWH', material: 'Airlaid', colour: 'white', price: 46.74, pac_size: 500, name: 'Airlaid White', active: true },
  { sku: '8FAIRBL', material: 'Airlaid', colour: 'black', price: 63.79, pac_size: 500, name: 'Airlaid Black', active: true },
  { sku: 'APIN-8-W', material: 'Airlaid Pocket', colour: 'white', price: 46.64, pac_size: 500, name: 'Airlaid Pocket White', active: true }
]

dinner_variants.each do |v|
  move_variant_to_product(new_product: dinner_napkins, **v)
end

# Attach variant photos
dinner_variant_photos = {
  '4FDINWH' => photos_base.join('paper-dinner-napkins/4FDINWH.webp'),
  '4FDINBL' => photos_base.join('paper-dinner-napkins/4FDINBL.webp'),
  '8FDINWH' => photos_base.join('premium-dinner-napkins/8FDINWH.webp'),
  '8FDINBL' => photos_base.join('premium-dinner-napkins/8FDINBL.webp'),
  '8FAIRWH' => photos_base.join('airlaid-napkins/8FAIRWH.webp'),
  '8FAIRBL' => photos_base.join('airlaid-napkins/8FAIRBL.webp'),
  'APIN-8-W' => photos_base.join('airlaid-pocket-napkins/APIN-8-W.webp')
}
dinner_variant_photos.each do |sku, photo_path|
  variant = ProductVariant.find_by(sku: sku)
  next unless variant && !variant.product_photo.attached?
  attach_photo(variant, :product_photo, photo_path)
end

puts "  ✓ Dinner Napkins: #{dinner_napkins.variants.reload.count} variants"

# =============================================================================
# 3. DISPENSER NAPKINS
# =============================================================================
dispenser_napkins = Product.unscoped.find_or_initialize_by(slug: 'dispenser-napkins')
dispenser_napkins.assign_attributes(
  name: 'Dispenser Napkins',
  category: napkins_category,
  product_type: 'standard',
  active: true,
  description_short: 'Single-sheet dispenser napkins for ice cream parlours and quick service.',
  description_standard: 'Economy 1-ply dispenser napkins ideal for ice cream shops, soft serve, and quick service restaurants. 33cm size fits standard napkin dispensers. 5000 napkins per case for high-volume use.',
  description_detailed: 'Our dispenser napkins are designed for high-volume quick service environments. The single-ply 33x33cm size fits standard napkin dispensers and provides practical functionality for ice cream parlours, fast food, and self-service areas. Each case contains 5000 napkins, making them the most economical choice for busy establishments where customers help themselves. The 4-fold design dispenses easily one napkin at a time. Perfect for soft serve counters, food courts, and any venue with napkin dispensers.',
  meta_title: 'Dispenser Napkins 33cm | 1-ply | Bulk 5000 | Afida',
  meta_description: 'Bulk dispenser napkins (33x33cm) for ice cream shops and quick service. 5000 per case. Fits standard dispensers. Free UK delivery over £100.'
)
dispenser_napkins.save!

# Attach product photo
unless dispenser_napkins.product_photo.attached?
  attach_photo(dispenser_napkins, :product_photo, photos_base.join('paper-napkins/main.webp'))
end

puts "  Creating Dispenser Napkins..."
# Dispenser napkin - move existing variant (single variant, no options needed)
move_variant_to_product(
  sku: '33-1-NAP',
  new_product: dispenser_napkins,
  name: 'Standard',
  material: 'Paper 1-ply',
  colour: 'white',
  price: 32.81,
  pac_size: 5000,
  active: true
)

# Attach variant photo
dispenser_variant = ProductVariant.find_by(sku: '33-1-NAP')
if dispenser_variant && !dispenser_variant.product_photo.attached?
  attach_photo(dispenser_variant, :product_photo, photos_base.join('paper-napkins/33-1-NAP.webp'))
end

puts "  ✓ Dispenser Napkins: #{dispenser_napkins.variants.reload.count} variant"

# =============================================================================
# 4. DEACTIVATE OLD NAPKIN PRODUCTS
# =============================================================================
old_napkin_slugs = %w[
  airlaid-cocktail-napkins
  airlaid-napkins
  airlaid-pocket-napkins
  bamboo-cocktail-napkins
  paper-cocktail-napkins
  paper-dinner-napkins
  paper-napkins
  premium-dinner-napkins
]

deactivated_count = 0
old_napkin_slugs.each do |slug|
  product = Product.unscoped.find_by(slug: slug)
  if product
    product.update!(active: false)
    product.variants.update_all(active: false)
    deactivated_count += 1
  end
end

puts "  ✓ Deactivated #{deactivated_count} old napkin products"

puts ""
puts "Napkin consolidation complete!"
puts "  New products: cocktail-napkins, dinner-napkins, dispenser-napkins"
puts "  Total variants: #{cocktail_napkins.variants.count + dinner_napkins.variants.count + dispenser_napkins.variants.count}"
