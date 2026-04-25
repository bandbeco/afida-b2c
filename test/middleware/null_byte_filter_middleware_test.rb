# frozen_string_literal: true

require "test_helper"

class NullByteFilterMiddlewareTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [ 200, { "Content-Type" => "text/html" }, [ "OK" ] ] }
    @middleware = NullByteFilterMiddleware.new(@app)
  end

  test "passes through requests without null bytes" do
    env = Rack::MockRequest.env_for("/?q=hello")
    status, _headers, body = @middleware.call(env)

    assert_equal 200, status
    assert_equal [ "OK" ], body
  end

  test "rejects request with null byte in query string" do
    env = Rack::MockRequest.env_for("/price-list?q=foo%00bar")
    status, _headers, body = @middleware.call(env)

    assert_equal 400, status
    assert_equal [ "Bad Request" ], body
  end

  test "rejects request with null byte in path" do
    env = Rack::MockRequest.env_for("/price-list%00")
    status, _headers, _body = @middleware.call(env)

    assert_equal 400, status
  end

  test "rejects request with null byte in form-encoded body" do
    env = Rack::MockRequest.env_for(
      "/cart/cart_items",
      method: "POST",
      input: "cart_item[sku]=ABC%00123&cart_item[quantity]=1",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, _headers, _body = @middleware.call(env)

    assert_equal 400, status
  end

  test "does not call downstream app when request rejected" do
    called = false
    app = ->(env) { called = true; [ 200, {}, [ "OK" ] ] }
    middleware = NullByteFilterMiddleware.new(app)

    env = Rack::MockRequest.env_for("/?q=foo%00")
    middleware.call(env)

    refute called, "Downstream app should not be called for rejected requests"
  end
end
