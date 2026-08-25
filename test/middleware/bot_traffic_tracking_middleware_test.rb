# frozen_string_literal: true

require "test_helper"

class BotTrafficTrackingMiddlewareTest < ActiveJob::TestCase
  GPTBOT_UA = "Mozilla/5.0 AppleWebKit/537.36; compatible; GPTBot/1.2; +https://openai.com/gptbot"
  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

  def setup
    @app = ->(env) { [ 200, { "Content-Type" => "text/html" }, [ "OK" ] ] }
    @middleware = BotTrafficTrackingMiddleware.new(@app)
  end

  test "enqueues a tracking job for a crawler request" do
    env = env_for("https://afida.com/paper-cups", user_agent: GPTBOT_UA)

    assert_enqueued_with(
      job: DatafastBotTrafficJob,
      args: [ { href: "https://afida.com/paper-cups", user_agent: GPTBOT_UA, ip: "203.0.113.10", status_code: 200 } ]
    ) do
      @middleware.call(env)
    end
  end

  test "passes the response through untouched" do
    env = env_for("https://afida.com/", user_agent: GPTBOT_UA)

    status, headers, body = @middleware.call(env)

    assert_equal 200, status
    assert_equal "text/html", headers["Content-Type"]
    assert_equal [ "OK" ], body
  end

  test "reports the response status code" do
    app = ->(env) { [ 404, { "Content-Type" => "text/html" }, [ "Not Found" ] ] }
    middleware = BotTrafficTrackingMiddleware.new(app)
    env = env_for("https://afida.com/missing", user_agent: GPTBOT_UA)

    assert_enqueued_with(job: DatafastBotTrafficJob) do
      middleware.call(env)
    end
    enqueued = enqueued_jobs.last
    assert_equal 404, enqueued[:args].first["status_code"]
  end

  test "tracks crawls that end in an exception, with the mapped status code" do
    app = ->(env) { raise ActiveRecord::RecordNotFound, "gone" }
    middleware = BotTrafficTrackingMiddleware.new(app)
    env = env_for("https://afida.com/products/deleted", user_agent: GPTBOT_UA)

    assert_raises ActiveRecord::RecordNotFound do
      middleware.call(env)
    end

    tracking_jobs = enqueued_jobs.select { |job| job[:job] == DatafastBotTrafficJob }
    assert_equal 1, tracking_jobs.size
    enqueued = tracking_jobs.last
    assert_equal 404, enqueued[:args].first["status_code"]
  end

  test "defers the enqueue to rack.after_reply when the server provides it" do
    env = env_for("https://afida.com/", user_agent: GPTBOT_UA)
    env["rack.after_reply"] = []

    assert_no_enqueued_jobs do
      @middleware.call(env)
    end
    assert_equal 1, env["rack.after_reply"].size

    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      env["rack.after_reply"].each(&:call)
    end
  end

  test "matches crawler tokens case-insensitively" do
    env = env_for("https://afida.com/", user_agent: "PerplexityBot/1.0")

    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      @middleware.call(env)
    end
  end

  test "matches known AI and search crawlers" do
    [ "Mozilla/5.0; compatible; ClaudeBot/1.0; +claudebot@anthropic.com",
      "cohere-ai/1.0",
      "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" ].each do |ua|
      env = env_for("https://afida.com/", user_agent: ua)

      assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
        @middleware.call(env)
      end
      clear_enqueued_jobs
    end
  end

  test "does not enqueue for a regular browser" do
    env = env_for("https://afida.com/", user_agent: BROWSER_UA)

    assert_no_enqueued_jobs do
      @middleware.call(env)
    end
  end

  test "does not enqueue for human or non-AI-crawler user agents containing bare bot words" do
    [ "Mozilla/5.0 (Linux; Android 10; Cubot X30 Build/QP1A.190711.020) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.185 Mobile Safari/537.36",
      "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)",
      "GoogleHC/1.0" ].each do |ua|
      env = env_for("https://afida.com/", user_agent: ua)

      assert_no_enqueued_jobs do
        @middleware.call(env)
      end
    end
  end

  test "does not enqueue when user agent is missing" do
    env = env_for("https://afida.com/")
    env.delete("HTTP_USER_AGENT")

    assert_no_enqueued_jobs do
      @middleware.call(env)
    end
  end

  test "scrubs invalid bytes from the user agent instead of dropping the crawl" do
    binary_ua = "GPTBot/1.2 \xE9".dup.force_encoding(Encoding::ASCII_8BIT)
    env = env_for("https://afida.com/", user_agent: binary_ua)

    assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
      @middleware.call(env)
    end
    enqueued = enqueued_jobs.last
    assert enqueued[:args].first["user_agent"].valid_encoding?
    assert_includes enqueued[:args].first["user_agent"], "GPTBot/1.2"
  end

  test "does not enqueue for asset paths, static assets, or the health check" do
    [ "https://afida.com/assets/application-abc123.css",
      "https://afida.com/rails/active_storage/blobs/abc",
      "https://afida.com/favicon.ico",
      "https://afida.com/apple-touch-icon.png",
      "https://afida.com/up" ].each do |url|
      env = env_for(url, user_agent: GPTBOT_UA)

      assert_no_enqueued_jobs do
        @middleware.call(env)
      end
    end
  end

  test "still tracks robots.txt, llms.txt, and sitemap.xml" do
    [ "https://afida.com/robots.txt", "https://afida.com/llms.txt", "https://afida.com/sitemap.xml" ].each do |url|
      env = env_for(url, user_agent: GPTBOT_UA)

      assert_enqueued_jobs 1, only: DatafastBotTrafficJob do
        @middleware.call(env)
      end
      clear_enqueued_jobs
    end
  end

  test "prefers the remote_ip computed by ActionDispatch over the socket address" do
    env = env_for("https://afida.com/", user_agent: GPTBOT_UA)
    env["REMOTE_ADDR"] = "10.0.0.1" # proxy address
    # ActionDispatch::RemoteIp stores a lazy GetIp object that resolves via #to_s
    env["action_dispatch.remote_ip"] = Class.new { def to_s = "203.0.113.10" }.new

    assert_enqueued_with(job: DatafastBotTrafficJob) do
      @middleware.call(env)
    end
    enqueued = enqueued_jobs.last
    assert_equal "203.0.113.10", enqueued[:args].first["ip"]
  end

  test "a tracking failure does not break the response" do
    DatafastBotTrafficJob.stubs(:perform_later).raises(StandardError, "queue down")
    env = env_for("https://afida.com/", user_agent: GPTBOT_UA)

    status, _headers, body = @middleware.call(env)

    assert_equal 200, status
    assert_equal [ "OK" ], body
  end

  private

  def env_for(url, user_agent: nil)
    env = Rack::MockRequest.env_for(url)
    env["HTTP_USER_AGENT"] = user_agent if user_agent
    env["REMOTE_ADDR"] = "203.0.113.10"
    env
  end
end
