# frozen_string_literal: true

class AgentLinkHeadersMiddleware
  LINKS = [
    '</.well-known/api-catalog>; rel="api-catalog"',
    '</openapi.json>; rel="service-desc"; type="application/vnd.oai.openapi+json"',
    '</llms.txt>; rel="service-doc"; type="text/plain"',
    '</.well-known/mcp/server-card.json>; rel="describedby"; type="application/json"'
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [ status, headers, body ] unless homepage?(env) && [ 200, 304 ].include?(status)

    headers = Rack::Headers[headers]
    existing = headers["link"].to_s
    additions = LINKS.join(", ")
    headers["link"] = existing.present? ? "#{existing}, #{additions}" : additions

    [ status, headers, body ]
  end

  private

  def homepage?(env)
    return false unless %w[GET HEAD].include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    path == "/" || path.empty?
  end
end
