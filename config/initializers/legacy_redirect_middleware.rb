# frozen_string_literal: true

# Require middleware file explicitly
require Rails.root.join("app/middleware/legacy_redirect_middleware")

# Register legacy redirect middleware early in stack for better performance
# Position: At the beginning of the stack, before routing
# Using insert 0 instead of insert_before to avoid dependency on ActionDispatch::Static
# which may not be present in production environments with config.public_file_server.enabled = false
Rails.application.config.middleware.insert 0, LegacyRedirectMiddleware
