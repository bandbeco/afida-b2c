# frozen_string_literal: true

require "test_helper"

class TelegramOrderNotificationJobTest < ActiveJob::TestCase
  setup do
    @order = orders(:one)
  end

  test "loads the order and notifies for it" do
    TelegramNotifier.expects(:notify_new_order).with { |o| o.id == @order.id }.once

    TelegramOrderNotificationJob.perform_now(@order.id)
  end

  test "does nothing when the order no longer exists" do
    TelegramNotifier.expects(:notify_new_order).never

    assert_nothing_raised do
      TelegramOrderNotificationJob.perform_now(-1)
    end
  end

  test "discards errors without retrying" do
    TelegramNotifier.stubs(:notify_new_order).raises(StandardError, "boom")

    assert_nothing_raised do
      TelegramOrderNotificationJob.perform_now(@order.id)
    end
  end
end
