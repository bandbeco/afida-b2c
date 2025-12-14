# frozen_string_literal: true

class PriceListController < ApplicationController
  allow_unauthenticated_access

  def index
    @variants = filtered_variants
    @categories = Category.where.not(slug: "branded-products").order(:position)
  end

  def export
    @variants = filtered_variants

    respond_to do |format|
      format.xlsx do
        render xlsx: "export", filename: "#{export_filename}.xlsx"
      end
      format.pdf do
        pdf = PriceListPdf.new(@variants, filter_description)
        send_data pdf.render,
                  filename: "#{export_filename}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  private

  def base_variant_scope
    ProductVariant.active
                  .joins(:product)
                  .where(products: { product_type: "standard", active: true })
  end

  def filtered_variants
    variants = base_variant_scope
                 .includes(product: :category)
                 .order("products.name ASC, product_variants.position ASC")

    variants = variants.where(products: { category_id: category_ids }) if params[:category].present?
    variants = search_variants(variants) if params[:q].present?

    variants
  end

  def category_ids
    Category.where(slug: params[:category]).pluck(:id)
  end

  def search_variants(variants)
    query = "%#{ProductVariant.sanitize_sql_like(params[:q])}%"
    variants.where(
      "products.name ILIKE ? OR product_variants.sku ILIKE ? OR product_variants.name ILIKE ?",
      query, query, query
    )
  end

  def export_filename
    parts = [ "afida-price-list" ]
    parts << params[:category].parameterize if params[:category].present?
    parts << Date.current.to_s
    parts.join("-")
  end

  def filter_description
    parts = []
    parts << Category.find_by(slug: params[:category])&.name if params[:category].present?
    parts << "\"#{params[:q]}\"" if params[:q].present?
    parts.any? ? "Filtered by: #{parts.join(', ')}" : "All products"
  end
end
