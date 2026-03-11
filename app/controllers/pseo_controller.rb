class PseoController < ApplicationController
  allow_unauthenticated_access

  def business_type
    slug = params[:business_type]

    raise ActionController::RoutingError, "Not Found" unless valid_slug?(slug)

    json_path = Rails.root.join("lib/data/pseo/pages/for/#{slug}.json")

    raise ActionController::RoutingError, "Not Found" unless json_path.exist?

    @page = JSON.parse(json_path.read, symbolize_names: true)
    @client_logos = helpers.client_logos
  end

  private

  def valid_slug?(slug)
    slug.present? && slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
  end
end
