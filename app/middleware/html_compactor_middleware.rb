# frozen_string_literal: true

class HtmlCompactorMiddleware
  COMMENT = /<!--.*?-->/m
  LINE_BREAK_WITH_INDENTATION = /[ \t\r]*\n[ \t\r\n]*/
  WHITESPACE_SENSITIVE_TAG = /<(?:pre|textarea)\b/i

  def initialize(app)
    @app = app
  end

  def call(env)
    head_request = env["REQUEST_METHOD"] == "HEAD"
    env = env_as_get(env) if head_request

    status, headers, body = @app.call(env)
    unless compactable?(status, headers)
      return [ status, headers, head_request ? empty_body(body) : body ]
    end

    html = read(body)
    if html.match?(WHITESPACE_SENSITIVE_TAG)
      return [ status, headers, head_request ? [] : [ html ] ]
    end

    compacted = compact(html)
    headers = Rack::Headers[headers]
    headers["content-length"] = compacted.bytesize.to_s
    [ status, headers, head_request ? [] : [ compacted ] ]
  end

  private

  def compactable?(status, headers)
    return false if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY[status]
    return false if header(headers, "Content-Encoding").present?

    header(headers, "Content-Type").to_s.include?("text/html")
  end

  def env_as_get(env)
    env.dup.tap do |get_env|
      get_env["REQUEST_METHOD"] = "GET"
      get_env.delete("action_dispatch.request")
    end
  end

  def empty_body(body)
    body.close if body.respond_to?(:close)
    []
  end

  def header(headers, name)
    Rack::Headers[headers][name]
  end

  def read(body)
    buffer = +""
    body.each { |part| buffer << part.to_s }
    buffer
  ensure
    body.close if body.respond_to?(:close)
  end

  def compact(html)
    html.gsub(COMMENT, "").gsub(LINE_BREAK_WITH_INDENTATION, "\n")
  end
end
