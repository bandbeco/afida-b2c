# frozen_string_literal: true

class PriceListController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = filtered_products
    @categories = Category.where.not(slug: "branded-products").order(:position)
  end

  def export
    @products = filtered_products

    respond_to do |format|
      format.xlsx do
        render xlsx: "export", filename: "#{export_filename}.xlsx"
      end
      format.pdf do
        pdf = PriceListPdf.new(@products, filter_description)
        send_data pdf.render,
                  filename: "#{export_filename}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  private

  def base_product_scope
    Product.active
           .catalog_products
  end

  def filtered_products
    products = base_product_scope
                 .includes(:category)
                 .order("products.name ASC, products.position ASC")

    products = products.where(category_id: category_ids) if params[:category].present?
    products = search_products(products) if params[:q].present?

    products
  end

  def category_ids
    Category.where(slug: params[:category]).pluck(:id)
  end

  def search_products(products)
    products.search(params[:q])
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
