# frozen_string_literal: true

# Require middleware file explicitly
require Rails.root.join("app/middleware/legacy_redirect_middleware")

# Register legacy redirect middleware
Rails.application.config.middleware.use LegacyRedirectMiddleware
