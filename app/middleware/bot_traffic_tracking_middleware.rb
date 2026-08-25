# frozen_string_literal: true

# Detects AI and search crawler requests by User-Agent and enqueues a
# DatafastBotTrafficJob to report them to DataFast's bot traffic API
# (https://datafa.st/docs/bot-traffic-tracking).
#
# The token match is only a cheap pre-filter to avoid enqueuing a job for
# every pageview; DataFast performs the authoritative classification
# (including IP range verification) server-side. Crawler-facing files like
# /robots.txt and /llms.txt are intentionally tracked; static assets and
# the health check are not.
class BotTrafficTrackingMiddleware
  # AI crawler tokens come from the AiCrawlers registry (shared with
  # robots.txt). DataFast also classifies search-engine and training
  # crawlers, so a few well-known non-AI crawler products are added here.
  # Tokens are specific product names, never bare words like "bot" or
  # "google" — those also appear in human User-Agents (e.g. Cubot phones)
  # and in SEO scanners DataFast would only discard.
  ADDITIONAL_CRAWLER_TOKENS = %w[
    googlebot googleother bingbot applebot duckduckbot
    anthropic bytespider ccbot amazonbot meta-externalagent
  ].freeze

  # Built lazily: this file is hand-required from an initializer, before
  # the autoloader can resolve AiCrawlers.
  def self.crawler_pattern
    @crawler_pattern ||= Regexp.new(
      Regexp.union(AiCrawlers.user_agent_tokens + ADDITIONAL_CRAWLER_TOKENS).source,
      Regexp::IGNORECASE
    )
  end

  SKIPPED_EXACT_PATHS = [ "/up" ].freeze
  SKIPPED_PATH_PREFIXES = [ "/assets/", "/rails/" ].freeze
  # Assets crawlers fetch alongside pages; .txt and .xml (robots, llms,
  # sitemaps) deliberately stay tracked.
  SKIPPED_EXTENSIONS = /\.(?:css|js|mjs|map|png|jpe?g|gif|svg|webp|avif|ico|woff2?|ttf|otf|eot)\z/i

  def initialize(app)
    @app = app
  end

  def call(env)
    user_agent = clean_user_agent(env)
    return @app.call(env) unless trackable?(user_agent, env)

    begin
      status, headers, body = @app.call(env)
    rescue StandardError => exception
      # An exception rising past this middleware still was a crawl; report
      # it with the status the exception renderer below will map it to
      # (RecordNotFound/RoutingError => 404, anything unknown => 500).
      schedule_tracking(env, user_agent, ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name))
      raise
    end

    schedule_tracking(env, user_agent, status)
    [ status, headers, body ]
  end

  private

  # Rack delivers headers as binary strings; odd bytes would fail JSON
  # serialization when the job arguments are encoded, silently dropping the
  # crawl, so re-encode to clean UTF-8 up front.
  def clean_user_agent(env)
    env["HTTP_USER_AGENT"].to_s.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def trackable?(user_agent, env)
    user_agent.match?(self.class.crawler_pattern) && !skipped_path?(env["PATH_INFO"].to_s)
  end

  def skipped_path?(path)
    SKIPPED_EXACT_PATHS.include?(path) ||
      SKIPPED_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) } ||
      path.match?(SKIPPED_EXTENSIONS)
  end

  # Tracking is best-effort and must never delay or break the response:
  # under Puma the enqueue is deferred to rack.after_reply, which runs after
  # the response has been flushed to the client; elsewhere it runs inline.
  # All failures are swallowed.
  def schedule_tracking(env, user_agent, status)
    after_reply = env["rack.after_reply"]
    if after_reply.is_a?(Array)
      after_reply << -> { enqueue_tracking(env, user_agent, status) }
    else
      enqueue_tracking(env, user_agent, status)
    end
  rescue StandardError => e
    log_failure(e)
  end

  def enqueue_tracking(env, user_agent, status)
    request = Rack::Request.new(env)
    DatafastBotTrafficJob.perform_later(
      href: request.url,
      user_agent: user_agent,
      ip: remote_ip(env, request),
      status_code: status
    )
  rescue StandardError => e
    log_failure(e)
  end

  # ActionDispatch::RemoteIp sees through proxy headers and mutates env
  # before the app runs, so its result is available here whenever the
  # request got that deep; fall back to Rack's ip (which also reads
  # X-Forwarded-For) for requests answered above it, e.g. static files.
  def remote_ip(env, request)
    (env["action_dispatch.remote_ip"] || request.ip).to_s.presence
  end

  def log_failure(error)
    Rails.logger.info("[DataFast] bot traffic enqueue failed: #{error.class} - #{error.message}")
  end
end
