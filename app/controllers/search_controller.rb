# Controller for header search dropdown with typeahead results
#
# Returns variant search results for the header search dropdown.
# Results are rendered within a Turbo Frame for live updates.
#
class SearchController < ApplicationController
  allow_unauthenticated_access

  # GET /search
  # Params:
  #   q - Search query (minimum 2 characters for results)
  # Returns:
  #   - Empty state if query < 2 chars
  #   - Up to 5 variant results matching query
  #   - Results rendered in Turbo Frame "search-results"
  def index
    @query = params[:q].to_s.strip

    if @query.length < 2
      @variants = []
    else
      @variants = ProductVariant
        .active
        .joins(:product)
        .where(products: { active: true, product_type: :standard })
        .search(@query)
        .includes(product: :category, product_photo_attachment: :blob)
        .limit(5)
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
