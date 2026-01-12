class RobotsController < ApplicationController
  allow_unauthenticated_access

  def show
    respond_to do |format|
      format.text do
        render plain: robots_txt_content, content_type: "text/plain"
      end
    end
  end

  private

  # Staging domains that should not be indexed by search engines
  # Add any staging/preview domains here to block search engine indexing
  STAGING_DOMAINS = %w[].freeze

  def robots_txt_content
    # Block all crawling on staging domains
    if staging_domain?
      return <<~ROBOTS
        User-agent: *
        Disallow: /
      ROBOTS
    end

    base_url = "#{request.protocol}#{request.host_with_port}"

    <<~ROBOTS
      User-agent: *
      Allow: /

      # Disallow admin and checkout areas
      Disallow: /admin/
      Disallow: /cart
      Disallow: /checkout

      # Sitemap
      Sitemap: #{base_url}/sitemap.xml
    ROBOTS
  end

  def staging_domain?
    STAGING_DOMAINS.any? { |domain| request.host.include?(domain) }
  end
end
