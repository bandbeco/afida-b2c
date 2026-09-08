# The product copy, identifiers and media shared by every outbound catalogue
# feed (Google Merchant XML, Stripe Agentic Commerce CSV). One place to compute
# them so the feeds describe the same product the same way.
class ProductFeedAttributes
  # Google Product Taxonomy IDs mapped to category slugs.
  # Full taxonomy: https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt
  #
  # Every id below is looked up in that file, and the test suite pins the whole
  # map. The previous ids were plausible-looking but WRONG across the entire
  # feed (4003 "napkins" was Martial Arts Uniforms, 4005 "food containers" was
  # Kitchen Tongs, 2228 did not exist), so never add an entry without quoting
  # the id's real taxonomy path from the file.
  #
  # Products resolve via their own category slug first, then the parent's
  # (google_product_category), so parent entries double as fallbacks for
  # any future child category.
  GOOGLE_TAXONOMY_MAP = {
    # Cups & Accessories
    "hot-cups" => "5099",              # Business & Industrial > Food Service > Disposable Tableware > Disposable Cups
    "cold-cups-and-lids" => "5099",    # Disposable Cups
    "ice-cream-cups" => "5099",        # Disposable Cups
    "cups-and-accessories" => "5099",  # Disposable Cups (parent)
    "hot-cup-lids" => "8059",          # Business & Industrial > Food Service > Disposable Lids
    "cup-accessories" => "7088",       # Business & Industrial > Food Service > Disposable Serving Accessories
    "straws" => "5043",                # Arts & Entertainment > Party & Celebration > Party Supplies > Drinking Straws & Stirrers
    "branded-products" => "5099",      # custom-printed cups -> Disposable Cups
    # Food Containers
    "food-containers" => "5097",       # Business & Industrial > Food Service > Takeaway Containers (parent)
    "food-containers-and-lids" => "5097", # Takeaway Containers
    "takeaway-boxes" => "5097",        # Takeaway Containers
    "soup-containers" => "5097",       # Takeaway Containers
    "pizza-boxes" => "5097",           # Takeaway Containers
    "bagasse-containers" => "5097",    # Takeaway Containers
    "aluminium-containers" => "5097",  # Takeaway Containers
    "portion-pots-and-lids" => "5097", # Takeaway Containers
    "bowls-and-lids" => "5098",        # Business & Industrial > Food Service > Disposable Tableware > Disposable Bowls
    # Cold Food & Salads
    "cold-food-and-salads" => "5097",  # Takeaway Containers (parent)
    "salad-boxes" => "5097",           # Takeaway Containers
    "deli-containers" => "5097",       # Takeaway Containers
    "sandwich-and-wrap-boxes" => "5097", # Takeaway Containers
    # Tableware
    "tableware" => "4632",             # Business & Industrial > Food Service > Disposable Tableware (parent)
    "plates-and-bowls" => "5101",      # Disposable Tableware > Disposable Plates
    "cutlery" => "5100",               # Disposable Tableware > Disposable Cutlery
    "napkins" => "3846",               # Home & Garden > Household Supplies > Household Paper Products > Paper Serviettes
    # Bags & Wraps
    "bags" => "1837",                  # Business & Industrial > Retail > Paper & Plastic Shopping Bags
    "bags-and-wraps" => "1837",        # Paper & Plastic Shopping Bags (parent)
    "natureflex-bags" => "3591",       # Home & Garden > Kitchen & Dining > Food Storage > Food Storage Bags
    "greaseproof-and-wraps" => "5642", # Home & Garden > Kitchen & Dining > Food Storage > Food Wraps > Parchment Paper
    # Supplies & Essentials
    "bin-liners" => "2374",            # Home & Garden > Household Supplies > Rubbish Bags
    "gloves-and-cleaning" => "623",    # Home & Garden > Household Supplies > Household Cleaning Supplies
    "labels-and-stickers" => "960",    # Office Supplies > General Office Supplies > Labels & Tags
    "till-rolls" => "5919",            # Office Supplies > ... > Receipt & Adding Machine Paper Rolls
    "supplies-and-essentials" => "623" # Household Cleaning Supplies (parent catch-all)
  }.freeze

  attr_reader :product

  def initialize(product)
    @product = product
  end

  def title
    parts = [ "Afida", product.generated_title ]

    if product.volume_in_ml.present?
      parts << "#{product.volume_in_ml}ml"
    elsif product.diameter_in_mm.present?
      parts << "#{product.diameter_in_mm}mm"
    elsif product.width_in_mm.present? && product.height_in_mm.present?
      parts << "#{product.width_in_mm}x#{product.height_in_mm}mm"
    end

    parts << product.material if product.material.present?
    parts << eco_feature
    parts << "#{product.pac_size} Pack" if product.pac_size.present?

    title = parts.compact.join(" ")
    title.length > 150 ? title[0..146] + "..." : title
  end

  def description
    product.description_detailed_with_fallback.presence || generated_description
  end

  def item_group_id
    if product.product_family.present?
      "FAMILY-#{product.product_family.id}"
    else
      "PROD-#{product.id}"
    end
  end

  def google_product_category
    return nil unless product.category

    GOOGLE_TAXONOMY_MAP[product.category.slug] ||
      (product.category.parent && GOOGLE_TAXONOMY_MAP[product.category.parent.slug])
  end

  def image_url
    image = product.product_photo.attached? ? product.product_photo : product.lifestyle_photo
    return "" unless image&.attached?

    url_for_image(image)
  end

  # Every attached photo other than the main one, in feed order.
  def additional_image_urls
    return [] unless product.product_photo.attached? && product.lifestyle_photo.attached?

    [ url_for_image(product.lifestyle_photo) ]
  end

  private

  def eco_feature
    text = product.description_detailed_with_fallback
    return "Compostable" if text&.match?(/compostable/i)

    "Biodegradable" if text&.match?(/biodegradable/i)
  end

  # The first 160 characters carry the essentials, because that is what ad
  # surfaces truncate to.
  def generated_description
    material = product.material.present? ? " Made from #{product.material}," : ""
    "Afida #{product.generated_title} are perfect for eco-conscious cafes and packaging businesses." \
      "#{material} fully compostable in commercial facilities. EN 13432 certified." \
      " Premium quality that your customers will notice - sturdy construction." \
      " Available in bulk packs for business use with competitive wholesale pricing." \
      " Free UK shipping on orders over #{Shipping.formatted_free_shipping_threshold}."
  end

  def url_for_image(image)
    if image.content_type == "image/webp"
      Rails.application.routes.url_helpers.url_for(image.variant(format: :jpeg))
    else
      Rails.application.routes.url_helpers.url_for(image)
    end
  end
end
