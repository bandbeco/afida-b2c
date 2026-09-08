# frozen_string_literal: true

class HtmlCompactorMiddleware
  COMMENT = /<!--.*?-->/m
  LINE_BREAK_WITH_INDENTATION = /[ \t\r]*\n[ \t\r\n]*/
  WHITESPACE_SENSITIVE_TAG = /<(?:pre|textarea)\b/i

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [ status, headers, body ] unless compactable?(env, status, headers)

    html = read(body)
    return [ status, headers, [ html ] ] if html.match?(WHITESPACE_SENSITIVE_TAG)

    compacted = compact(html)
    headers = headers.dup
    headers["Content-Length"] = compacted.bytesize.to_s
    [ status, headers, [ compacted ] ]
  end

  private

  def compactable?(env, status, headers)
    return false if env["REQUEST_METHOD"] == "HEAD"
    return false if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY[status]
    return false if header(headers, "Content-Encoding").present?

    header(headers, "Content-Type").to_s.include?("text/html")
  end

  def header(headers, name)
    headers[name] || headers[name.downcase]
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
