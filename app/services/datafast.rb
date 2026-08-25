# frozen_string_literal: true

require "http"

# Shared DataFast configuration and HTTP client, used by DatafastService
# (goals API), DatafastBotTrafficService (bot traffic API), and the
# client-side script tag in app/views/layouts/application.html.erb.
module Datafast
  # The public tracking property this site reports to. WEBSITE_ID is the
  # DataFast property id; DOMAIN is the property's registered domain (not
  # the request host — staging also reports here, like the client script).
  WEBSITE_ID = "dfid_1CWdt0k6kD3HqR911G1Im"
  DOMAIN = "afida.com"

  TIMEOUT_SECONDS = 5

  # Configured HTTP client with the shared timeout; adds Bearer auth when a
  # token is given. Note HTTP::TimeoutError < HTTP::Error, so callers only
  # need to rescue HTTP::Error.
  def self.http_client(auth_token = nil)
    client = HTTP.timeout(TIMEOUT_SECONDS)
    auth_token.present? ? client.auth("Bearer #{auth_token}") : client
  end
end
