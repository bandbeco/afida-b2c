# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Only send errors in production (avoids SSL errors and noise in dev/test)
  config.enabled_environments = %w[production]

  # Capture 10% of transactions for performance monitoring
  config.traces_sample_rate = 0.1

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-collected/ for more info
  config.send_default_pii = true

  # Set environment
  config.environment = Rails.env

  # Enable async sending
  config.background_worker_threads = 5
end
