# frozen_string_literal: true

require Rails.root.join("app/middleware/markdown_for_agents_middleware")

Rails.application.config.middleware.use MarkdownForAgentsMiddleware
