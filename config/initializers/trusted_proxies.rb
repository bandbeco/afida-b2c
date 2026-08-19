# afida.com is served through Cloudflare, so the peer that opens the connection to our
# proxy is a Cloudflare edge node, not the visitor. ActionDispatch::RemoteIp reads
# X-Forwarded-For from the right and returns the first address that is not a trusted
# proxy, so until the Cloudflare ranges are listed here, request.remote_ip resolves to
# an edge node.
#
# That is not cosmetic. Every per-IP throttle in this app buckets on remote_ip
# (registrations, sessions, cart items, checkout, the newsletter signup), so they would
# all share a handful of edge addresses: simultaneously too strict for real customers
# and no obstacle at all to a distributed attacker. Session#ip_address — the only record
# of who registered — would likewise store an edge node, making it useless for
# attribution.
#
# Two details worth keeping in mind before editing:
#
#   * Assigning an enumerable REPLACES Rails' defaults rather than extending them
#     (action_dispatch/middleware/remote_ip.rb:86), so TRUSTED_PROXIES is re-included
#     explicitly. kamal-proxy's own hop arrives on the Docker bridge and must stay
#     filtered, or remote_ip would become a container address.
#
#   * Trusting these ranges is not a spoofing vector, because the list is read
#     right-to-left and the proxy appends the true peer address to the right-hand end.
#     Anything a client injects sits to the left of it and is never reached. This does
#     depend on the fronting proxy appending rather than overwriting; kamal-proxy, via
#     Go's httputil.ReverseProxy, appends.
#
# Refresh the ranges with:
#   curl -s https://www.cloudflare.com/ips-v4 https://www.cloudflare.com/ips-v6
# Last refreshed 2026-08-19.
cloudflare_ranges = %w[
  173.245.48.0/20
  103.21.244.0/22
  103.22.200.0/22
  103.31.4.0/22
  141.101.64.0/18
  108.162.192.0/18
  190.93.240.0/20
  188.114.96.0/20
  197.234.240.0/22
  198.41.128.0/17
  162.158.0.0/15
  104.16.0.0/13
  104.24.0.0/14
  172.64.0.0/13
  131.0.72.0/22
  2400:cb00::/32
  2606:4700::/32
  2803:f800::/32
  2405:b500::/32
  2405:8100::/32
  2a06:98c0::/29
  2c0f:f248::/32
].map { |range| IPAddr.new(range) }

Rails.application.config.action_dispatch.trusted_proxies =
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + cloudflare_ranges
