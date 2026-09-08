# frozen_string_literal: true

require Rails.root.join("app/middleware/html_compactor_middleware")

# Above the exception renderer so the static 404 page is compacted too.
Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, HtmlCompactorMiddleware
