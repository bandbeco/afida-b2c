# frozen_string_literal: true

# Legacy URL Redirects from old afida.com site
# This file contains mappings from legacy product URLs to new product structure
#
# Format:
# {
#   legacy_path: "/product/old-url-pattern",
#   target_slug: "new-product-slug",
#   variant_params: { size: "12\"", colour: "Kraft" }  # Optional
# }
#
# TODO: Replace these example mappings with actual 63 URLs from results.json

legacy_redirects = [
  # Example mappings - these should be replaced with actual 63 URLs from results.json
  # These use actual product slugs from the database
  {
    legacy_path: "/product/12-310-x-310mm-pizza-box",
    target_slug: "pizza-box",
    variant_params: { size: "12\"" }
  },
  {
    legacy_path: "/product/14-360-x-360mm-pizza-box",
    target_slug: "pizza-box",
    variant_params: { size: "14\"" }
  },
  {
    legacy_path: "/product/branded-double-wall-cups-8oz",
    target_slug: "double-wall-branded-cups",
    variant_params: { size: "8oz" }
  },
  {
    legacy_path: "/product/branded-double-wall-cups-12oz",
    target_slug: "double-wall-branded-cups",
    variant_params: { size: "12oz" }
  },
  {
    legacy_path: "/product/bio-fibre-drinking-straws",
    target_slug: "bio-fibre-straws",
    variant_params: {}
  }
  # TODO: Add remaining 58 mappings from results.json
  # Process: Review results.json, match to current product slugs, extract size/colour
]

puts "Seeding legacy redirects..."

legacy_redirects.each do |data|
  LegacyRedirect.find_or_create_by!(legacy_path: data[:legacy_path]) do |redirect|
    redirect.target_slug = data[:target_slug]
    redirect.variant_params = data[:variant_params] || {}
    redirect.active = true
  end
end

puts "✅ Seeded #{legacy_redirects.count} legacy redirects"
puts "   Active: #{LegacyRedirect.active.count}"
puts "   Total: #{LegacyRedirect.count}"
