module ApplicationHelper
  def category_icon_path(category)
    icon_mapping = {
      "cups-and-lids" => "images/graphics/cold-cups.svg",
      "ice-cream-cups" => "images/graphics/ice-cream-cups.svg",
      "napkins" => "images/graphics/napkins.svg",
      "pizza-boxes" => "images/graphics/pizza-boxes.svg",
      "straws" => "images/graphics/straws.svg",
      "takeaway-containers" => "images/graphics/kraft-food-containers.svg",
      "takeaway-extras" => "images/graphics/take-away-extras.svg"
    }

    icon_mapping[category.slug]
  end

  # Returns the appropriate path for a product based on its type.
  # Branded products (customizable_template) link to /branded-products/:slug
  # Standard products link to /products/:slug
  def search_result_path(product)
    if product.customizable_template?
      branded_product_path(product)
    else
      product_path(product)
    end
  end
end
