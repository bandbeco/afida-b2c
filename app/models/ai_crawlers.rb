# frozen_string_literal: true

# Canonical registry of the AI crawlers this site caters to — the single
# source of truth for the two places that must stay in sync:
#
# - RobotsController renders one robots.txt stanza per crawler
# - BotTrafficTrackingMiddleware matches crawler User-Agents to report
#   visits to DataFast
#
# Add new crawlers here rather than in either consumer.
module AiCrawlers
  # robots_token: the User-agent product token used in robots.txt.
  # ua_token: substring (lowercase) of the crawler's real User-Agent header;
  #   nil for robots-only tokens whose fetches arrive under another
  #   product's User-Agent (Google-Extended, Applebot-Extended) or that are
  #   already covered by a broader token (Claude-Web by "claude").
  # restricted: whether the robots.txt stanza repeats the site-wide disallows.
  Crawler = Data.define(:robots_token, :ua_token, :restricted)

  REGISTRY = [
    Crawler.new(robots_token: "GPTBot", ua_token: "gptbot", restricted: true),
    Crawler.new(robots_token: "ChatGPT-User", ua_token: "chatgpt", restricted: false),
    Crawler.new(robots_token: "OAI-SearchBot", ua_token: "oai-searchbot", restricted: false),
    Crawler.new(robots_token: "ClaudeBot", ua_token: "claude", restricted: true),
    Crawler.new(robots_token: "Claude-Web", ua_token: nil, restricted: false),
    Crawler.new(robots_token: "PerplexityBot", ua_token: "perplexity", restricted: true),
    Crawler.new(robots_token: "Google-Extended", ua_token: nil, restricted: false),
    Crawler.new(robots_token: "Applebot-Extended", ua_token: nil, restricted: false),
    Crawler.new(robots_token: "cohere-ai", ua_token: "cohere", restricted: false),
    Crawler.new(robots_token: "Diffbot", ua_token: "diffbot", restricted: false)
  ].freeze

  def self.user_agent_tokens
    REGISTRY.filter_map(&:ua_token)
  end
end
