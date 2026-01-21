# frozen_string_literal: true

# Helper methods for client-side DataFast goal tracking.
#
# These methods generate JavaScript for tracking events that occur
# on page load (view_item) where server-side tracking is not feasible
# because they don't trigger controller actions.
#
# Usage in views:
#   <script><%= datafast_view_item_goal(@product) %></script>
#
# The DataFast script (loaded in application.html.erb) exposes a global
# `datafast()` function for client-side goal tracking.
#
module DatafastHelper
  # Generates JavaScript for view_item goal (product detail page)
  # @param product [Product] The product being viewed
  # @return [String] JavaScript code (html_safe)
  def datafast_view_item_goal(product)
    return "".html_safe unless datafast_enabled?

    metadata = {
      product_id: product.id.to_s,
      product_sku: product.sku
    }

    datafast_goal_js("view_item", metadata)
  end

  private

  def datafast_enabled?
    Rails.application.credentials.dig(:datafast, :api_key).present?
  end

  # Generates JavaScript that calls the DataFast client-side API
  # Uses optional chaining to avoid errors if script hasn't loaded
  def datafast_goal_js(name, metadata)
    <<~JS.html_safe
      window.datafast?.("#{name}", #{metadata.to_json});
    JS
  end
end
