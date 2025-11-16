class BlogsController < ApplicationController
  # Public blog pages - no authentication required
  allow_unauthenticated_access

  def index
    # Fetch all published ContentItems from the engine, ordered by published_at desc
    @posts = SeoAiEngine::ContentItem.where.not(published_at: nil).order(published_at: :desc)
  end

  def show
    # Find ContentItem by slug
    @content_item = SeoAiEngine::ContentItem.find_by!(slug: params[:id])

    # Load related products if IDs are present
    @related_products = if @content_item.related_product_ids.present?
      Product.where(id: @content_item.related_product_ids)
    else
      []
    end

    # Set meta tags for SEO
    set_meta_tags(@content_item)
  end

  private

  def set_meta_tags(content_item)
    @page_title = content_item.meta_title.presence || content_item.title
    @meta_description = content_item.meta_description.presence || content_item.title
  end
end
