class SitemapsController < ApplicationController
  allow_unauthenticated_access
  # Crawler-only XML endpoint: no visitor to attribute, so don't emit a tracking cookie.
  skip_before_action :ensure_datafast_visitor_id

  def show
    @sitemap_xml = SitemapGeneratorService.new.generate

    respond_to do |format|
      format.xml { render xml: @sitemap_xml }
    end
  end
end
