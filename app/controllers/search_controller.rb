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
      # (name matches first) and popularity (units sold). Each matching product
      # is its own row: a ProductFamily groups products that serve the same
      # purpose, not size variants of one model, so search does not collapse a
      # family into one row (issue #253). The limit and the "Showing X of Y"
      # count therefore apply to one row per matching product.
      ranked = Product
        .active
        .catalog_products
        .search_ranked(@query)
        .includes(:product_family, :category, product_photo_attachment: :blob)

      all_rows = ranked.map { |product| SearchResultRow.new([ product ]) }

      # Before the modal declares "no results", widen the net to category names
      # via search_extended (issue #251). A query like "coffee shops" may name no
      # product but match a category, so this rescues an otherwise dead end.
      # Scoped to the modal: the compact header dropdown keeps to direct matches
      # so it never surfaces a product whose name has nothing to do with the
      # query (matched only via its category) with no room to explain why.
      all_rows = extended_rows if @modal && all_rows.empty?

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

  # Category-aware fallback rows for a query that matched no product directly.
  # Uses search_extended (which also searches category names) and ranks by the
  # same relevance ordering as the primary path (by_relevance) so the two search
  # paths agree, wrapping each product in its own row like the primary path.
  def extended_rows
    extended = Product
      .active
      .catalog_products
      .search_extended(@query)
      .by_relevance(@query)
      .includes(:product_family, :category, product_photo_attachment: :blob)

    extended.map { |product| SearchResultRow.new([ product ]) }
  end

  def render_appropriate_template
    if @modal
      render :modal, layout: false
    else
      render :index
    end
  end
end
