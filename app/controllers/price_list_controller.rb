# frozen_string_literal: true

class PriceListController < ApplicationController
  allow_unauthenticated_access

  def index
    @pagy, @products = pagy(filtered_products)
    @categories = Category.top_level.where.not(slug: "branded-products")
                          .includes(:children).order(:position)
  end

  def export
    @products = all_products

    respond_to do |format|
      format.xlsx do
        render xlsx: "export", filename: "afida-price-list-#{Date.current}.xlsx"
      end
      format.pdf do
        pdf = PriceListPdf.new(@products, "All products")
        send_data pdf.render,
                  filename: "afida-price-list-#{Date.current}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  private

  def all_products
    base_product_scope
      .includes(category: { image_attachment: :blob })
      .joins(:category)
      .order("categories.name ASC, products.name ASC, products.position ASC")
  end

  def base_product_scope
    Product.active
           .standard
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
end
