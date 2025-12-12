# frozen_string_literal: true

class PriceListController < ApplicationController
  allow_unauthenticated_access

  def index
    @variants = filtered_variants
    @categories = Category.where.not(slug: "branded-products").order(:position)
    @materials = available_materials
    @sizes = available_sizes
  end

  def export
    @variants = filtered_variants

    respond_to do |format|
      format.xlsx do
        response.headers["Content-Disposition"] = "attachment; filename=\"#{export_filename}.xlsx\""
        render xlsx: "export", layout: false
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

  def filtered_variants
    variants = ProductVariant.active
                             .joins(:product)
                             .includes(product: :category)
                             .where(products: { product_type: "standard", active: true })
                             .order("products.name ASC, product_variants.position ASC")

    variants = variants.where(products: { category_id: category_ids }) if params[:category].present?
    variants = filter_by_material(variants) if params[:material].present?
    variants = filter_by_size(variants) if params[:size].present?
    variants = search_variants(variants) if params[:q].present?

    variants
  end

  def category_ids
    Category.where(slug: params[:category]).pluck(:id)
  end

  def filter_by_material(variants)
    variants.where("product_variants.option_values->>'material' = ?", params[:material])
  end

  def filter_by_size(variants)
    variants.where("product_variants.option_values->>'size' = ?", params[:size])
  end

  def search_variants(variants)
    query = "%#{ProductVariant.sanitize_sql_like(params[:q])}%"
    variants.where(
      "products.name ILIKE ? OR product_variants.sku ILIKE ? OR product_variants.name ILIKE ?",
      query, query, query
    )
  end

  def available_materials
    ProductVariant.active
                  .joins(:product)
                  .where(products: { product_type: "standard", active: true })
                  .pluck(Arel.sql("DISTINCT product_variants.option_values->>'material'"))
                  .compact
                  .sort
  end

  def available_sizes
    ProductVariant.active
                  .joins(:product)
                  .where(products: { product_type: "standard", active: true })
                  .pluck(Arel.sql("DISTINCT product_variants.option_values->>'size'"))
                  .compact
                  .sort_by { |s| s.scan(/\d+/).first&.to_i || 999 }
  end

  def export_filename
    parts = [ "afida-price-list" ]
    parts << params[:category] if params[:category].present?
    parts << Date.current.to_s
    parts.join("-")
  end

  def filter_description
    parts = []
    parts << Category.find_by(slug: params[:category])&.name if params[:category].present?
    parts << params[:material] if params[:material].present?
    parts << params[:size] if params[:size].present?
    parts << "\"#{params[:q]}\"" if params[:q].present?
    parts.any? ? "Filtered by: #{parts.join(', ')}" : "All products"
  end
end
