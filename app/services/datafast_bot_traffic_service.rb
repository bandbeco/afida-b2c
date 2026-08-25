# frozen_string_literal: true

# Reports AI crawler visits (GPTBot, ClaudeBot, PerplexityBot, ...) to
# DataFast's bot traffic API. These crawlers never run the client-side
# analytics script, so they are invisible to normal pageview tracking and
# must be reported server-side instead.
#
# API Reference: https://datafa.st/docs/bot-traffic-tracking
#
# Usage:
#   DatafastBotTrafficService.track(href: "https://afida.com/paper-cups",
#                                   user_agent: "GPTBot/1.2", ip: "1.2.3.4", status_code: 200)
#
class DatafastBotTrafficService
  ENDPOINT = "https://datafa.st/api/ai-crawls"

  class << self
    # @param href [String] Full URL the crawler requested
    # @param user_agent [String] The request's User-Agent header
    # @param ip [String, nil] Crawler's source IP, used by DataFast to verify official ranges
    # @param status_code [Integer, nil] Response status code
    # @return [Boolean] true if the crawl was recorded
    def track(href:, user_agent:, ip: nil, status_code: nil)
      new(href: href, user_agent: user_agent, ip: ip, status_code: status_code).track
    end
  end

  def initialize(href:, user_agent:, ip: nil, status_code: nil)
    @href = href
    @user_agent = user_agent
    @ip = ip
    @status_code = status_code
  end

  def track
    if @href.blank? || @user_agent.blank?
      log_error("href or user_agent is blank")
      return false
    end

    send_crawl
  rescue HTTP::Error => e
    log_error("HTTP error: #{e.class} - #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error: #{e.class} - #{e.message}")
    false
  end

  private

  def send_crawl
    response = Datafast.http_client(auth_token).post(ENDPOINT, json: payload)

    if response.status.success?
      true
    else
      log_error("API returned #{response.status}: #{response.body}")
      false
    end
  end

  def payload
    {
      websiteId: Datafast::WEBSITE_ID,
      domain: Datafast::DOMAIN,
      href: @href,
      ai: {
        userAgent: @user_agent,
        ip: @ip,
        statusCode: @status_code,
        source: "server_middleware"
      }.compact
    }
  end

  # Only required once "Require authentication" is switched on in the
  # DataFast bot traffic settings; without a configured token the request
  # is sent unauthenticated.
  def auth_token
    Rails.application.credentials.dig(:datafast, :bot_traffic_token)
  end

  def log_error(message)
    Rails.logger.info("[DataFast] FAILED ai_crawl href='#{@href}' error='#{message}'")
  end
end
