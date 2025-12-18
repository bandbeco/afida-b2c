# Deactivate old products that have had their variants moved to consolidated products
# Run with: rails runner db/seeds/deactivate_old_products.rb

old_slugs = [
  "paper-cocktail-napkins", "airlaid-cocktail-napkins", "bamboo-cocktail-napkins",
  "airlaid-napkins", "airlaid-pocket-napkins",
  "paper-straws", "bio-fibre-straws", "bamboo-pulp-straws",
  "wooden-forks", "wooden-knives", "wooden-spoons", "wooden-cutlery-kits"
]

old_slugs.each do |slug|
  p = Product.unscoped.find_by(slug: slug)
  next unless p
  next if p.variants.any?

  p.update!(active: false)
  puts "Deactivated: #{slug}"
end

puts "\nDone!"
