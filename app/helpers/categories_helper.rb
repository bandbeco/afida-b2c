# Helper methods for category display
module CategoriesHelper
  # Map category slugs to their SVG icon paths
  # These icons are used in the category nav bar and samples page
  CATEGORY_ICONS = {
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
    "cups-and-lids" => %w[napkins straws takeaway-extras],
    "ice-cream-cups" => %w[takeaway-extras napkins],
    "napkins" => %w[cups-and-lids takeaway-containers straws],
    "pizza-boxes" => %w[napkins takeaway-extras],
    "straws" => %w[cups-and-lids napkins],
    "takeaway-containers" => %w[napkins takeaway-extras cups-and-lids],
    "takeaway-extras" => %w[takeaway-containers cups-and-lids napkins]
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
