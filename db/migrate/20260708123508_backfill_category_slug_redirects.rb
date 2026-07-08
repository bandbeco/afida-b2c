class BackfillCategorySlugRedirects < ActiveRecord::Migration[8.1]
  # Old slug => current slug of the category that owns it. Mirrors the static
  # redirect maps in config/routes.rb (June 2026 restructure + legacy flat
  # slugs) so the DB slug history is a complete record and controllers that
  # resolve categories by slug (categories, collections vegware filter,
  # samples) can 301 these without route-level entries.
  BACKFILL = {
    "cups-and-drinks" => "cups-and-accessories",
    "hot-food" => "food-containers",
    "cold-cups" => "cold-cups-and-lids",
    "deli-pots" => "deli-containers",
    "plates-and-trays" => "plates-and-bowls",
    "food-bowls" => "bowls-and-lids",
    "round-containers-lids" => "food-containers-and-lids",
    "portion-pots-lids" => "portion-pots-and-lids",
    "bowls-lids" => "bowls-and-lids",
    "food-containers-lids" => "food-containers-and-lids",
    "cups-and-lids" => "cups-and-accessories",
    "takeaway-containers" => "food-containers",
    "takeaway-extras" => "supplies-and-essentials",
    "plates-trays" => "plates-and-bowls",
    "bagasse-eco-range" => "bagasse-containers"
  }.freeze

  def up
    BACKFILL.each do |old_slug, target_slug|
      # A redirect must never shadow a live slug.
      next if Category.exists?(slug: old_slug)

      target = Category.find_by(slug: target_slug)
      next unless target

      redirect = CategorySlugRedirect.find_or_initialize_by(old_slug: old_slug)
      redirect.update!(category: target)
    end
  end

  def down
    CategorySlugRedirect.where(old_slug: BACKFILL.keys).delete_all
  end
end
