# frozen_string_literal: true

require Rails.root.join("app/middleware/security_headers_middleware")

Rails.application.config.middleware.use SecurityHeadersMiddleware
