# frozen_string_literal: true

require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "connect-src allows Google Ads conversion endpoints" do
    get root_url
    csp = response.headers["Content-Security-Policy"] || response.headers["Content-Security-Policy-Report-Only"]
    connect_src = csp.split(";").find { |d| d.strip.start_with?("connect-src") }

    assert_includes connect_src, "https://www.googleadservices.com"
    assert_includes connect_src, "https://googleads.g.doubleclick.net"
  end
end
