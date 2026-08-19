require "test_helper"

# afida.com is fronted by Cloudflare, so the peer that connects to our proxy is a
# Cloudflare edge node rather than the visitor. ActionDispatch::RemoteIp walks
# X-Forwarded-For from the right and returns the first address that is not a trusted
# proxy, so unless the Cloudflare ranges are trusted, request.remote_ip is an edge node.
#
# That is not cosmetic: every per-IP throttle in this app (registrations, sessions,
# cart items, checkout, newsletter) buckets on remote_ip, and Session#ip_address — the
# only record of who signed up — stores it.
#
# These assert through the session record because that is the app's real consumer of
# remote_ip. Headers are written as Rails receives them: in production kamal-proxy has
# already appended the connecting peer to the right-hand end.
class RemoteIpTest < ActionDispatch::IntegrationTest
  VISITOR = "203.0.113.9"
  CLOUDFLARE_EDGE = "172.68.1.1"

  setup do
    @user = users(:one)
  end

  test "resolves to the visitor rather than the Cloudflare edge node" do
    sign_in_forwarded_for("#{VISITOR}, #{CLOUDFLARE_EDGE}")

    assert_equal VISITOR, latest_session_ip
  end

  # A client can put anything in X-Forwarded-For and Cloudflare appends the true client
  # address to the right of it. Because the list is read right-to-left, the injected
  # value is never reached.
  test "an X-Forwarded-For entry injected by the client cannot displace the visitor" do
    sign_in_forwarded_for("9.9.9.9, #{VISITOR}, #{CLOUDFLARE_EDGE}")

    assert_equal VISITOR, latest_session_ip
  end

  # The origin is still reachable without going through Cloudflare, so this path is live.
  test "a request that did not pass through Cloudflare still resolves to its peer" do
    sign_in_forwarded_for(VISITOR)

    assert_equal VISITOR, latest_session_ip
  end

  # Trusting the Cloudflare ranges would be a spoofing vector if the rightmost entry
  # were attacker-controlled. It is not: whatever they send, the proxy appends the real
  # peer address after it, and that is what is read first.
  test "a forged Cloudflare hop cannot hide the real peer" do
    sign_in_forwarded_for("198.51.100.7, 104.16.0.1, #{VISITOR}")

    assert_equal VISITOR, latest_session_ip
  end

  private

  def sign_in_forwarded_for(chain)
    post session_url,
         params: { email_address: @user.email_address, password: "password" },
         headers: { "HTTP_X_FORWARDED_FOR" => chain }
  end

  def latest_session_ip
    @user.sessions.order(:created_at).last&.ip_address
  end
end
