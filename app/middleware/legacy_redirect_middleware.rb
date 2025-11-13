# frozen_string_literal: true

class LegacyRedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Only intercept GET/HEAD requests to /product/* paths
    return @app.call(env) unless %w[GET HEAD].include?(request.request_method)
    return @app.call(env) unless request.path.start_with?("/product/")

    # Normalize path (remove trailing slash) and lookup redirect
    normalized_path = request.path.chomp("/")
    redirect = LegacyRedirect.active.find_by_path(normalized_path)

    # Pass through if no active redirect found
    unless redirect
      Rails.logger.info("LegacyRedirectMiddleware: No mapping found for #{normalized_path}")
      return @app.call(env)
    end

    # Increment hit counter (fire-and-forget)
    increment_hit_counter(redirect)

    # Build target URL with preserved query parameters
    target_url = build_target_url(redirect, request)

    # Return 301 redirect
    [ 301, redirect_headers(target_url), [ "Redirecting..." ] ]
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    Rails.logger.error("LegacyRedirectMiddleware: #{e.class} - #{e.message}")
    @app.call(env)  # Fail open
  end

  private

  def increment_hit_counter(redirect)
    redirect.record_hit!
  rescue => e
    Rails.logger.warn("LegacyRedirectMiddleware: Hit counter update failed - #{e.message}")
  end

  def build_target_url(redirect, request)
    url = "/products/#{redirect.target_slug}"

    all_params = redirect.variant_params.dup || {}
    if request.query_string.present?
      existing_params = Rack::Utils.parse_query(request.query_string)
      all_params.merge!(existing_params)
    end

    url += "?#{Rack::Utils.build_query(all_params)}" if all_params.present?
    url
  end

  def redirect_headers(location)
    {
      "Location" => location,
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "public, max-age=86400"
    }
  end
end
