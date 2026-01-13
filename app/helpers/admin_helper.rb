module AdminHelper
  def sort_link(label, column)
    direction = if @sort_column == column && @sort_direction == "asc"
      "desc"
    else
      "asc"
    end

    # Build URL preserving search params
    url_params = { sort: column, direction: direction }
    url_params[:search] = params[:search] if params[:search].present?

    link_class = "flex items-center gap-1 hover:text-primary"
    link_class += " font-bold" if @sort_column == column

    link_to admin_products_path(url_params), class: link_class do
      concat label
      if @sort_column == column
        concat sort_indicator(@sort_direction)
      end
    end
  end

  private

  def sort_indicator(direction)
    if direction == "asc"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-4 h-4") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M4.5 15.75l7.5-7.5 7.5 7.5")
      end
    else
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor", class: "w-4 h-4") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M19.5 8.25l-7.5 7.5-7.5-7.5")
      end
    end
  end
end
