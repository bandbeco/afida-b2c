# Controller for search functionality
#
# Supports two modes:
# - Header dropdown: Compact results (5 items) for quick navigation
# - Modal: Expanded results (10 items) with total count for "view all"
#
class SearchController < ApplicationController
  allow_unauthenticated_access

  # GET /search
  # Params:
  #   q - Search query (minimum 2 characters for results)
  #   modal - If "true", returns modal-optimized results (10 items)
  # Returns:
  #   - Empty state if query < 2 chars
  #   - Product results matching query
  #   - Results rendered in appropriate Turbo Frame
  def index
    @query = params[:q].to_s.strip
    @modal = params[:modal] == "true"

    if @query.length < 2
      @rows = []
      @total_count = 0
    else
      # search_ranked reapplies the :search filter, then orders by relevance
      # (name matches first) and popularity (units sold). Collapse size/colour
      # variants that share a ProductFamily into one row (issue #247), so the
      # limit and the "Showing X of Y" count apply to ROWS DISPLAYED, not raw
      # SKUs. Relevance order is preserved: a family takes the rank of its
      # best-ranked member (its first appearance in the ranked list).
      ranked = Product
        .active
        .catalog_products
        .search_ranked(@query)
        .includes(:product_family, :category, product_photo_attachment: :blob)

      all_rows = SearchResultRow.collapse(ranked)
      @total_count = all_rows.size

      # Modal shows more results than the header dropdown.
      limit = @modal ? 10 : 5
      @rows = all_rows.first(limit)
    end

    respond_to do |format|
      format.html { render_appropriate_template }
      format.turbo_stream
    end
  end

  private

  def render_appropriate_template
    if @modal
      render :modal, layout: false
    else
      render :index
    end
  end
end
