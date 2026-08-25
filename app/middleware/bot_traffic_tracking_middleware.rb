# frozen_string_literal: true

# Detects likely AI crawler / bot requests by User-Agent and enqueues a
# DatafastBotTrafficJob to report them to DataFast's bot traffic API
# (https://datafa.st/docs/bot-traffic-tracking).
#
# The keyword list is only a cheap pre-filter to avoid enqueuing a job for
# every human pageview; DataFast performs the authoritative classification
# (including IP range verification) server-side. Crawler-facing files like
# /robots.txt and /llms.txt are intentionally tracked; static assets are not.
class BotTrafficTrackingMiddleware
  CRAWLER_KEYWORDS = %w[
    bot crawler spider chatgpt gptbot claude perplexity bing google
    applebot bytespider ccbot
  ].freeze
  CRAWLER_PATTERN = Regexp.union(CRAWLER_KEYWORDS)
  SKIPPED_PATH_PREFIXES = [ "/assets/", "/rails/" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    track_crawler(env, status)
    [ status, headers, body ]
  end

  private

  # Tracking is best-effort and must never delay or break the response:
  # the enqueue happens after the app has responded and swallows all errors.
  def track_crawler(env, status)
    user_agent = env["HTTP_USER_AGENT"].to_s
    return unless crawler?(user_agent)
    return if skipped_path?(env["PATH_INFO"].to_s)

    request = Rack::Request.new(env)
    DatafastBotTrafficJob.perform_later(
      href: request.url,
      user_agent: user_agent,
      ip: remote_ip(env, request),
      status_code: status
    )
  rescue StandardError => e
    Rails.logger.info("[DataFast] bot traffic enqueue failed: #{e.class} - #{e.message}")
  end

  def crawler?(user_agent)
    return false if user_agent.empty?

    user_agent.downcase.match?(CRAWLER_PATTERN)
  end

  def skipped_path?(path)
    SKIPPED_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }
  end

  # ActionDispatch::RemoteIp runs earlier in the stack and sees through
  # proxy headers; fall back to the socket address outside of it.
  def remote_ip(env, request)
    (env["action_dispatch.remote_ip"] || request.ip).to_s.presence
  end
end
