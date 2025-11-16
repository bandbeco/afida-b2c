class BlogsController < ApplicationController
  # Public blog pages - no authentication required
  allow_unauthenticated_access

  def index
    # Eager load association to prevent N+1 queries
    @posts = SeoAiEngine::ContentItem
      .includes(:content_draft)
      .where.not(published_at: nil)
      .order(published_at: :desc)
  end

  def show
    # Handle not found gracefully (no stack trace exposure)
    @content_item = SeoAiEngine::ContentItem.find_by(slug: params[:id])

    unless @content_item
      redirect_to blogs_path, alert: "Blog post not found"
      return
    end

    # Sanitize and validate product IDs to prevent SQL injection
    @related_products = []
    if @content_item.related_product_ids.present?
      safe_product_ids = @content_item.related_product_ids
        .map { |id| id.to_i }
        .select { |id| id.positive? }
        .uniq

      @related_products = Product.where(id: safe_product_ids) if safe_product_ids.any?
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
