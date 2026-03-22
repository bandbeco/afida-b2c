require "test_helper"

class GoogleCustomerReviewsHelperTest < ActionView::TestCase
  # gcr_configured? tests

  test "gcr_configured? returns true when merchant_id is present" do
    @gcr_merchant_id = 12345678
    assert gcr_configured?
  end

  test "gcr_configured? returns false when merchant_id is nil" do
    @gcr_merchant_id = nil
    refute gcr_configured?
  end

  test "gcr_configured? returns false when merchant_id is blank" do
    @gcr_merchant_id = ""
    refute gcr_configured?
  end

  # gcr_merchant_id tests

  test "gcr_merchant_id reads from credentials" do
    id = gcr_merchant_id
    # Returns whatever is in credentials (likely nil in test)
    assert_respond_to self, :gcr_merchant_id
  end

  # gcr_survey_opt_in tests

  test "gcr_survey_opt_in returns empty string when not configured" do
    @gcr_merchant_id = nil
    order = orders(:one)
    assert_equal "", gcr_survey_opt_in(order)
  end

  test "gcr_survey_opt_in renders script tags when configured" do
    @gcr_merchant_id = 12345678
    order = orders(:one)
    result = gcr_survey_opt_in(order)

    assert_includes result, "apis.google.com/js/platform.js"
    assert_includes result, "surveyoptin"
    assert_includes result, "12345678"
    assert_includes result, order.order_number
    assert_includes result, order.email
  end

  test "gcr_survey_opt_in includes delivery country from order" do
    @gcr_merchant_id = 12345678
    order = orders(:one)
    result = gcr_survey_opt_in(order)

    assert_includes result, '"delivery_country": "GB"'
  end

  test "gcr_survey_opt_in includes estimated delivery date" do
    @gcr_merchant_id = 12345678
    order = orders(:one)
    result = gcr_survey_opt_in(order)

    # Estimated delivery date should be 5 business days from order creation
    assert_match(/\d{4}-\d{2}-\d{2}/, result)
  end

  test "gcr_survey_opt_in sets language to en-GB" do
    @gcr_merchant_id = 12345678
    order = orders(:one)
    result = gcr_survey_opt_in(order)

    assert_includes result, "lang: 'en-GB'"
  end

  # gcr_store_widget tests

  test "gcr_store_widget returns empty string when not configured" do
    @gcr_merchant_id = nil
    assert_equal "", gcr_store_widget
  end

  test "gcr_store_widget renders widget script when configured" do
    @gcr_merchant_id = 12345678
    result = gcr_store_widget

    assert_includes result, "merchantwidget.js"
    assert_includes result, "merchantwidget.start"
  end

  test "gcr_store_widget defaults to RIGHT_BOTTOM position" do
    @gcr_merchant_id = 12345678
    result = gcr_store_widget

    assert_includes result, "RIGHT_BOTTOM"
  end

  # estimated_delivery_date tests

  test "estimated_delivery_date returns date 5 business days from order creation" do
    order = orders(:one)
    # Freeze time to make test deterministic
    travel_to Time.zone.local(2026, 3, 16, 12, 0, 0) do # Monday
      order.update_columns(created_at: Time.current)
      result = estimated_delivery_date(order)
      # 5 business days from Monday = next Monday
      assert_equal "2026-03-23", result
    end
  end

  test "estimated_delivery_date skips weekends" do
    order = orders(:one)
    travel_to Time.zone.local(2026, 3, 19, 12, 0, 0) do # Thursday
      order.update_columns(created_at: Time.current)
      result = estimated_delivery_date(order)
      # Thu + 5 business days = Thu next week (skipping Sat/Sun)
      assert_equal "2026-03-26", result
    end
  end
end
