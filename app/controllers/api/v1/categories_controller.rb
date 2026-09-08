# frozen_string_literal: true

module Api
  module V1
    class CategoriesController < ApplicationController
      rate_limit to: 120, within: 1.minute, with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

      def index
        render json: catalog.categories
      end

      def show
        render json: catalog.category(params[:slug])
      end
    end
  end
end
