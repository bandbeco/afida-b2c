# frozen_string_literal: true

require "test_helper"

class SecurityHeadersMiddlewareTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [ 200, { "Content-Type" => "text/html" }, [ "OK" ] ] }
    @middleware = SecurityHeadersMiddleware.new(@app)
  end

  test "sets Cross-Origin-Opener-Policy header" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)

    assert_equal "same-origin", headers["Cross-Origin-Opener-Policy"]
  end

  test "sets X-Content-Type-Options header" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)

    assert_equal "nosniff", headers["X-Content-Type-Options"]
  end

  test "sets Referrer-Policy header" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)

    assert_equal "strict-origin-when-cross-origin", headers["Referrer-Policy"]
  end

  test "sets Permissions-Policy header" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)

    assert_equal "camera=(), microphone=(), geolocation=()", headers["Permissions-Policy"]
  end

  test "preserves existing response headers" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)

    assert_equal "text/html", headers["Content-Type"]
  end

  test "preserves response status and body" do
    env = Rack::MockRequest.env_for("/")
    status, _headers, body = @middleware.call(env)

    assert_equal 200, status
    assert_equal [ "OK" ], body
  end
end
