# frozen_string_literal: true

module Api
  module Internal
    module V1
      class ApplicationController < ActionController::API
        include ApiTokenAuthentication

        rescue_from ActionDispatch::Http::Parameters::ParseError do
          render json: { error: "Invalid JSON body" }, status: :bad_request
        end
      end
    end
  end
end
