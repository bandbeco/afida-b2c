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

  # Returns the Vite asset path for a category's icon
  #
  # @param category [Category, String] Category object or slug string
  # @return [String] Vite asset path for the icon
  def category_icon_path(category)
    slug = category.respond_to?(:slug) ? category.slug : category.to_s
    CATEGORY_ICONS[slug] || DEFAULT_CATEGORY_ICON
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
