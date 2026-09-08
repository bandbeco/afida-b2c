# frozen_string_literal: true

require Rails.root.join("app/middleware/markdown_for_agents_middleware")

# Above the exception renderer so 404s served by the exceptions app are
# converted for agents as well as ordinary pages.
Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, MarkdownForAgentsMiddleware
