# frozen_string_literal: true

require "test_helper"

class SentryInitializerTest < ActiveSupport::TestCase
  # sentry-rails 7 turns Rails structured logging on by default, which would
  # start shipping every production query and controller action to Sentry as
  # log events. Keep that an explicit decision rather than an upgrade default.
  test "Rails structured logging is not shipped to Sentry" do
    refute Sentry.configuration.rails.structured_logging.enabled?
  end
end
