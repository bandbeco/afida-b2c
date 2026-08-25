# frozen_string_literal: true

require "test_helper"

class DatafastBotTrafficJobTest < ActiveJob::TestCase
  test "calls DatafastBotTrafficService.track with correct arguments" do
    DatafastBotTrafficService.expects(:track).with(
      href: "https://afida.com/paper-cups",
      user_agent: "GPTBot/1.2",
      ip: "203.0.113.10",
      status_code: 200
    ).once

    DatafastBotTrafficJob.perform_now(
      href: "https://afida.com/paper-cups",
      user_agent: "GPTBot/1.2",
      ip: "203.0.113.10",
      status_code: 200
    )
  end

  test "discards errors without retrying" do
    DatafastBotTrafficService.stubs(:track).raises(StandardError, "API error")

    assert_nothing_raised do
      DatafastBotTrafficJob.perform_now(href: "https://afida.com/", user_agent: "GPTBot", ip: nil, status_code: 200)
    end
  end
end
