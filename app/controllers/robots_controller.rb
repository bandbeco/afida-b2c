class RobotsController < ApplicationController
  allow_unauthenticated_access
  # Crawler-only text endpoint: no visitor to attribute, so don't emit a tracking cookie.
  skip_before_action :ensure_datafast_visitor_id

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

  CONTENT_SIGNAL = "Content-Signal: ai-train=yes, search=yes, ai-input=yes"

  DISALLOW_RULES = <<~RULES
    Disallow: /admin/
    Disallow: /cart
    Disallow: /checkout
    Disallow: /signin
    Disallow: /signup
  RULES

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
      #{CONTENT_SIGNAL}
      Allow: /

      # Disallow admin and checkout areas
      #{DISALLOW_RULES.strip}

      # AI Search Engine Crawlers - Explicitly Allowed
      #{ai_crawler_sections.strip}

      # Sitemap
      Sitemap: #{base_url}/sitemap.xml
    ROBOTS
  end

  # One stanza per crawler in the shared AiCrawlers registry, which also
  # drives BotTrafficTrackingMiddleware's User-Agent matching.
  def ai_crawler_sections
    AiCrawlers::REGISTRY.map { |crawler| ai_crawler_section(crawler) }.join("\n")
  end

  def ai_crawler_section(crawler)
    section = +"User-agent: #{crawler.robots_token}\n#{CONTENT_SIGNAL}\nAllow: /\n"
    section << DISALLOW_RULES if crawler.restricted
    section
  end

  def staging_domain?
    STAGING_DOMAINS.any? { |domain| request.host.include?(domain) }
  end
end
