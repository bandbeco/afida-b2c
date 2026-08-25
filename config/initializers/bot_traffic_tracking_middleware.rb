# frozen_string_literal: true

require Rails.root.join("app/middleware/bot_traffic_tracking_middleware")

# Reports AI crawler visits to DataFast (see BotTrafficTrackingMiddleware).
# Placed above ActionDispatch::Static so crawls of static files in public/
# — notably /llms.txt, the most crawler-targeted file on the site — are
# seen. This also puts it above the exception renderer, so crawls of stale
# URLs (production 404s) come back as ordinary status codes instead of
# raising past the tracker.
Rails.application.config.middleware.insert_before ActionDispatch::Static, BotTrafficTrackingMiddleware
