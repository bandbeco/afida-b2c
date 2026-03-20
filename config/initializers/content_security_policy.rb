# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https

    policy.font_src :self, :https, :data

    policy.img_src :self, :https, :data

    policy.object_src :none

    # GTM requires unsafe-inline and unsafe-eval for its dynamically injected tags.
    # The external domains cover GTM itself, Google Analytics, Google Ads,
    # DataFast analytics, Google Customer Reviews, and the Cloudflare challenge platform.
    policy.script_src :self,
                      :unsafe_inline,
                      :unsafe_eval,
                      "https://www.googletagmanager.com",
                      "https://www.google-analytics.com",
                      "https://www.googleadservices.com",
                      "https://googleads.g.doubleclick.net",
                      "https://datafa.st",
                      "https://apis.google.com",
                      "https://www.gstatic.com"

    policy.style_src :self, :https, :unsafe_inline

    # connect-src: where JS can send requests (fetch, XHR, WebSocket)
    policy.connect_src :self,
                       "https://www.google-analytics.com",
                       "https://analytics.google.com",
                       "https://www.googletagmanager.com",
                       "https://datafa.st",
                       "https://*.sentry.io"

    # frame-src: GTM noscript iframe and Google Customer Reviews
    policy.frame_src :self,
                     "https://www.googletagmanager.com",
                     "https://td.doubleclick.net",
                     "https://apis.google.com"

    # Allow @vite/client to hot reload javascript changes in development
    if Rails.env.development?
      policy.script_src *policy.script_src, "http://#{ViteRuby.config.host_with_port}"
      policy.style_src *policy.style_src, :unsafe_inline
      policy.connect_src *policy.connect_src, "ws://#{ViteRuby.config.host_with_port}"
    end

    policy.script_src *policy.script_src, :blob if Rails.env.test?
  end

  # Start in report-only mode to catch issues before enforcing.
  # Change to false once verified in production.
  config.content_security_policy_report_only = true
end
