# frozen_string_literal: true

module Api
  module Internal
    module V1
      class ApplicationController < ActionController::API
        include ApiTokenAuthentication
      end
    end
  end
end
