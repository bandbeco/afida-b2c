# frozen_string_literal: true

# Production category tree as of the 2026-08-20 sitemap. Aluminium containers
# live under food-containers, not tableware.
module LiveTaxonomy
  TREE = {
    "bags-and-wraps" => %w[bags greaseproof-and-wraps natureflex-bags],
    "cold-food-and-salads" => %w[deli-containers salad-boxes sandwich-and-wrap-boxes],
    "cups-and-accessories" => %w[cold-cups-and-lids cup-accessories hot-cup-lids hot-cups ice-cream-cups straws],
    "food-containers" => %w[aluminium-containers bagasse-containers bowls-and-lids food-containers-and-lids
                            pizza-boxes portion-pots-and-lids soup-containers takeaway-boxes],
    "supplies-and-essentials" => %w[bin-liners gloves-and-cleaning labels-and-stickers till-rolls],
    "tableware" => %w[cutlery napkins plates-and-bowls]
  }.freeze
end
