# frozen_string_literal: true

# Require middleware file explicitly
require Rails.root.join("app/middleware/legacy_redirect_middleware")

# Register legacy redirect middleware early in stack for better performance
# Position: After Static file serving, before routing
Rails.application.config.middleware.insert_before ActionDispatch::Static, LegacyRedirectMiddleware
