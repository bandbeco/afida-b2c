# Helper methods for category display
module CategoriesHelper
  # Map category slugs to their SVG icon paths
  # These icons are used in the category nav bar and samples page
  CATEGORY_ICONS = {
    # Top-level parent categories (new hierarchy)
    "cups-and-drinks" => "images/graphics/cold-cups.svg",
    "hot-food" => "images/graphics/kraft-food-containers.svg",
    "cold-food-and-salads" => "images/graphics/box.svg",
    "tableware" => "images/graphics/napkins.svg",
    "bags-and-wraps" => "images/graphics/take-away-extras.svg",
    "supplies-and-essentials" => "images/graphics/box.svg",
    "branded-packaging" => "images/graphics/box.svg",
    "vegware" => "images/graphics/box.svg",
    # Legacy/subcategory slugs (still used on subcategory pages, samples page, etc.)
    "cups-and-lids" => "images/graphics/cold-cups.svg",
    "ice-cream-cups" => "images/graphics/ice-cream-cups.svg",
    "napkins" => "images/graphics/napkins.svg",
    "pizza-boxes" => "images/graphics/pizza-boxes.svg",
    "straws" => "images/graphics/straws.svg",
    "takeaway-containers" => "images/graphics/kraft-food-containers.svg",
    "takeaway-extras" => "images/graphics/take-away-extras.svg"
  }.freeze

  DEFAULT_CATEGORY_ICON = "images/graphics/box.svg".freeze

  # Pastel background colors for category cards (index-based cycling)
  # Order: green, pink, blue, orange, red, yellow, purple
  CATEGORY_PASTEL_COLORS = [
    "#d1fae5", # pastel green
    "#fce7f3", # pastel pink
    "#dbeafe", # pastel blue
    "#ffedd5", # pastel orange
    "#fee2e2", # pastel red
    "#fef9c3", # pastel yellow
    "#ede9fe"  # pastel purple
  ].freeze

  # Related category mappings for "You might also need" sections
  # Maps category slugs to arrays of related category slugs
  # Used to improve internal linking and cross-selling
  RELATED_CATEGORIES = {
    # Cups & Drinks subcategories
    "hot-cups" => %w[cup-lids cup-accessories napkins],
    "cold-cups" => %w[cup-lids straws napkins],
    "cup-lids" => %w[hot-cups cold-cups cup-accessories],
    "cup-accessories" => %w[cup-lids hot-cups cold-cups],
    "ice-cream-cups" => %w[napkins cutlery cold-cups],
    "straws" => %w[cold-cups cup-lids napkins],
    # Hot Food subcategories
    "pizza-boxes" => %w[napkins greaseproof-and-wraps bags],
    "takeaway-boxes" => %w[napkins cutlery bags],
    "food-containers" => %w[napkins cutlery bags],
    "soup-containers" => %w[napkins cutlery hot-cups],
    "bagasse-containers" => %w[napkins cutlery greaseproof-and-wraps],
    # Cold Food & Salads subcategories
    "salad-boxes" => %w[napkins cutlery deli-pots],
    "sandwich-and-wrap-boxes" => %w[napkins bags greaseproof-and-wraps],
    "deli-pots" => %w[salad-boxes napkins cutlery],
    # Tableware subcategories
    "plates-and-trays" => %w[napkins cutlery aluminium-containers],
    "cutlery" => %w[napkins plates-and-trays takeaway-boxes],
    "napkins" => %w[cutlery plates-and-trays hot-cups],
    "aluminium-containers" => %w[plates-and-trays napkins greaseproof-and-wraps],
    # Bags & Wraps subcategories
    "bags" => %w[greaseproof-and-wraps napkins labels-and-stickers],
    "greaseproof-and-wraps" => %w[bags napkins natureflex-bags],
    "natureflex-bags" => %w[bags greaseproof-and-wraps labels-and-stickers],
    # Supplies & Essentials subcategories
    "bin-liners" => %w[gloves-and-cleaning labels-and-stickers],
    "labels-and-stickers" => %w[bags natureflex-bags till-rolls],
    "gloves-and-cleaning" => %w[bin-liners napkins],
    "till-rolls" => %w[labels-and-stickers bags]
  }.freeze

  # Returns related categories for cross-linking
  # @param category [Category] The current category
  # @return [Array<Category>] Array of related Category objects
  def related_categories_for(category)
    return [] unless category

    related_slugs = RELATED_CATEGORIES[category.slug] || []
    return [] if related_slugs.empty?

    Category.where(slug: related_slugs).order(:position)
  end

  # Returns the Vite asset path for a category's icon
  #
  # @param category [Category, String] Category object or slug string
  # @return [String] Vite asset path for the icon
  def category_icon_path(category)
    slug = category.respond_to?(:slug) ? category.slug : category.to_s
    CATEGORY_ICONS[slug] || DEFAULT_CATEGORY_ICON
  end

  # Returns a pastel background color for a category card based on its index
  #
  # @param index [Integer] The category's position in the list (0-indexed)
  # @return [String] Hex color code
  def category_pastel_color(index)
    CATEGORY_PASTEL_COLORS[index % CATEGORY_PASTEL_COLORS.length]
  end

  # Returns the browse path for a category, using nested URLs for subcategories
  #
  # @param category [Category] Category object
  # @return [String] URL path like /categories/hot-food or /categories/hot-food/pizza-boxes
  def category_browse_path(category)
    if category.parent.present?
      category_subcategory_path(category.parent.slug, category.slug)
    else
      category_path(category)
    end
  end

  # Returns the browse URL for a category (absolute), using nested URLs for subcategories
  def category_browse_url(category)
    if category.parent.present?
      category_subcategory_url(category.parent.slug, category.slug)
    else
      category_url(category)
    end
  end

  # Question-style headings for category pages (GEO optimization)
  # These help AI search engines understand what the page answers
  CATEGORY_QUESTION_HEADINGS = {
    # Top-level parents
    "cups-and-drinks" => "What eco-friendly cups and drinks packaging does Afida offer?",
    "hot-food" => "What eco-friendly hot food packaging does Afida offer?",
    "cold-food-and-salads" => "What eco-friendly cold food and salad packaging does Afida offer?",
    "tableware" => "What eco-friendly tableware does Afida offer?",
    "bags-and-wraps" => "What eco-friendly bags and wraps does Afida offer?",
    "supplies-and-essentials" => "What catering supplies and essentials does Afida offer?",
    # Subcategories
    "hot-cups" => "What eco-friendly hot cups does Afida offer?",
    "cold-cups" => "What eco-friendly cold cups does Afida offer?",
    "cup-lids" => "What cup lids does Afida offer?",
    "cup-accessories" => "What cup accessories does Afida offer?",
    "ice-cream-cups" => "What eco-friendly ice cream cups does Afida offer?",
    "straws" => "What eco-friendly straws does Afida offer?",
    "pizza-boxes" => "What eco-friendly pizza boxes does Afida offer?",
    "takeaway-boxes" => "What eco-friendly takeaway boxes does Afida offer?",
    "food-containers" => "What eco-friendly food containers does Afida offer?",
    "soup-containers" => "What eco-friendly soup containers does Afida offer?",
    "bagasse-containers" => "What compostable bagasse containers does Afida offer?",
    "salad-boxes" => "What eco-friendly salad boxes does Afida offer?",
    "sandwich-and-wrap-boxes" => "What eco-friendly sandwich and wrap boxes does Afida offer?",
    "deli-pots" => "What eco-friendly deli pots does Afida offer?",
    "plates-and-trays" => "What eco-friendly plates and trays does Afida offer?",
    "cutlery" => "What eco-friendly cutlery does Afida offer?",
    "napkins" => "What eco-friendly napkins does Afida offer?",
    "aluminium-containers" => "What aluminium containers does Afida offer?",
    "bags" => "What eco-friendly paper bags does Afida offer?",
    "greaseproof-and-wraps" => "What greaseproof paper and wraps does Afida offer?",
    "natureflex-bags" => "What compostable NatureFlex bags does Afida offer?",
    "bin-liners" => "What bin liners does Afida offer?",
    "labels-and-stickers" => "What labels and stickers does Afida offer?",
    "gloves-and-cleaning" => "What gloves and cleaning supplies does Afida offer?",
    "till-rolls" => "What till rolls does Afida offer?"
  }.freeze

  # Returns a question-style heading for a category page
  # Used as an H2 below the category name H1 for GEO optimization
  #
  # @param category [Category] The category
  # @return [String] A question-phrased heading
  def category_question_heading(category)
    CATEGORY_QUESTION_HEADINGS[category.slug] || "What #{category.name} products does Afida offer?"
  end

  # Renders a category icon image tag
  #
  # @param category [Category, String] Category object or slug string
  # @param options [Hash] Options passed to vite_image_tag (class, alt, etc.)
  # @return [String] HTML image tag
  def category_icon_tag(category, **options)
    name = category.respond_to?(:name) ? category.name : category.to_s.titleize
    options[:alt] ||= "#{name} icon"
    options[:class] ||= "w-6 h-6 object-contain"

    vite_image_tag(category_icon_path(category), **options)
  end
end
