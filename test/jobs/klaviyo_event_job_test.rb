# frozen_string_literal: true

require "test_helper"

class KlaviyoEventJobTest < ActiveJob::TestCase
  test "track operation calls KlaviyoService.track with keyword args" do
    KlaviyoService.expects(:track).with(
      "Subscribed",
      email: "buyer@cafe.co.uk",
      properties: { source: "cart_discount" },
      value: nil
    ).once

    KlaviyoEventJob.perform_now(
      "track",
      metric: "Subscribed",
      email: "buyer@cafe.co.uk",
      properties: { source: "cart_discount" }
    )
  end

  test "track operation forwards a monetary value" do
    KlaviyoService.expects(:track).with(
      "Placed Order",
      email: "buyer@cafe.co.uk",
      properties: {},
      value: 119.99
    ).once

    KlaviyoEventJob.perform_now(
      "track",
      metric: "Placed Order",
      email: "buyer@cafe.co.uk",
      value: 119.99
    )
  end

  test "upsert_profile operation calls KlaviyoService.upsert_profile" do
    KlaviyoService.expects(:upsert_profile).with(
      email: "buyer@cafe.co.uk",
      first_name: "Jane",
      last_name: nil,
      properties: { is_business: true }
    ).once

    KlaviyoEventJob.perform_now(
      "upsert_profile",
      email: "buyer@cafe.co.uk",
      first_name: "Jane",
      properties: { is_business: true }
    )
  end

  test "discards errors without retrying" do
    KlaviyoService.stubs(:track).raises(StandardError, "API error")

    assert_nothing_raised do
      KlaviyoEventJob.perform_now("track", metric: "Subscribed", email: "buyer@cafe.co.uk")
    end
  end

  test "ignores unknown operations" do
    KlaviyoService.expects(:track).never
    KlaviyoService.expects(:upsert_profile).never

    assert_nothing_raised do
      KlaviyoEventJob.perform_now("nonsense", email: "buyer@cafe.co.uk")
    end
  end
end
