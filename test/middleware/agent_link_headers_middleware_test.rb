# frozen_string_literal: true

require "test_helper"

class AgentLinkHeadersMiddlewareTest < ActiveSupport::TestCase
  def setup
    @app = ->(_env) { [ 200, { "Content-Type" => "text/html" }, [ "OK" ] ] }
    @middleware = AgentLinkHeadersMiddleware.new(@app)
  end

  test "adds agent relation types on the homepage" do
    env = Rack::MockRequest.env_for("/")
    _status, headers, _body = @middleware.call(env)
    link = headers["Link"] || headers["link"]

    %w[api-catalog service-desc service-doc describedby].each do |rel|
      assert_match(/rel="#{rel}"/, link)
    end
  end

  test "leaves other paths unchanged" do
    env = Rack::MockRequest.env_for("/shop")
    _status, headers, _body = @middleware.call(env)
    link = headers["Link"] || headers["link"]

    assert_nil link
  end
end
