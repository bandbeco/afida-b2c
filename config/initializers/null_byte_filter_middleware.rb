# frozen_string_literal: true

require Rails.root.join("app/middleware/null_byte_filter_middleware")

Rails.application.config.middleware.insert 0, NullByteFilterMiddleware
