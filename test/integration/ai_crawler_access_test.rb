# frozen_string_literal: true

require "test_helper"
require "useragent"

class AiCrawlerAccessTest < ActionDispatch::IntegrationTest
  CRAWLER_USER_AGENTS = {
    "ChatGPT-User" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; ChatGPT-User/1.0; +https://openai.com/bot",
    "GPTBot" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)",
    "OAI-SearchBot" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; OAI-SearchBot/1.0; +https://openai.com/searchbot",
    "ClaudeBot" => "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)",
    "Claude-User" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; Claude-User/1.0; +Claude-User@anthropic.com",
    "PerplexityBot" => "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; PerplexityBot/1.0; +https://perplexity.ai/perplexitybot)",
    "Google-Extended" => "Mozilla/5.0 (compatible; Google-Extended)",
    "DeepSeekBot" => "Mozilla/5.0 (compatible; DeepSeekBot/1.0; +https://www.deepseek.com)",
    "bare token" => "ClaudeBot"
  }.freeze

  CRAWLER_USER_AGENTS.each do |name, user_agent|
    test "#{name} can fetch the homepage" do
      get root_path, headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_select "h1"
    end

    test "#{name} is not rejected by the production browser allow-list" do
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent))
      blocker = ActionController::AllowBrowser::BrowserBlocker.new(request, versions: :modern)

      refute blocker.blocked?, "#{user_agent.inspect} would get a 406 in production"
    end
  end

  test "robots.txt explicitly allows every audited crawler" do
    get "/robots.txt"

    %w[ChatGPT-User ClaudeBot GPTBot PerplexityBot Google-Extended].each do |token|
      assert_includes response.body, "User-agent: #{token}\n"
    end
  end
end
