# frozen_string_literal: true

module Api
  module V1
    class ProductsController < ApplicationController
      rate_limit to: 120, within: 1.minute, with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

      def index
        render json: catalog.products(
          query: params[:q],
          category: params[:category],
          page: params[:page],
          per_page: params[:per_page]
        )
      end

      def show
        render json: catalog.product(params[:slug])
      end
    end
  end
end
