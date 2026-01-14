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
      @products = []
      @total_count = 0
    else
      base_query = Product
        .active
        .catalog_products
        .search(@query)

      # Get total count for "view all" link
      @total_count = base_query.count

      # Modal shows more results than header dropdown
      limit = @modal ? 10 : 5

      @products = base_query
        .includes(:category, product_photo_attachment: :blob)
        .order(Arel.sql("CASE WHEN product_type = 'customizable_template' THEN 0 ELSE 1 END"))
        .limit(limit)
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
