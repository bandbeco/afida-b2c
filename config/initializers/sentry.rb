# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.enabled_environments = %w[production staging]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-collected/ for more info
  config.send_default_pii = true

  # Set environment
  config.environment = Rails.env

  # Enable async sending (optional but recommended)
  config.background_worker_threads = 5
end
