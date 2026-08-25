# frozen_string_literal: true

require Rails.root.join("app/middleware/bot_traffic_tracking_middleware")

# Reports AI crawler visits to DataFast (see BotTrafficTrackingMiddleware).
# Sits at the bottom of the stack so requests already answered higher up
# (static files, redirects) are not reported.
Rails.application.config.middleware.use BotTrafficTrackingMiddleware
