# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < Agent::BaseController
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end
    end
  end
end
