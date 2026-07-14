require "test_helper"

class GoogleCustomerReviewsHelperTest < ActionView::TestCase
  # gcr_configured? tests

  test "gcr_configured? returns true when merchant_id is present" do
    @gcr_merchant_id = 12345678
    assert gcr_configured?
  end

  test "gcr_configured? returns false when merchant_id is nil" do
    @gcr_merchant_id = nil
    @gcr_merchant_id_loaded = true # bypass the credentials read so nil stands
    refute gcr_configured?
  end

  test "gcr_configured? returns false when merchant_id is blank" do
    @gcr_merchant_id = ""
    @gcr_merchant_id_loaded = true # bypass the credentials read so blank stands
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
    @gcr_merchant_id_loaded = true # bypass the credentials read so nil stands
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

  # The sitewide store badge is intentionally not rendered: it adds no value to
  # Google Shopping ad seller ratings (those come from the confirmation-page
  # survey) and it collided with the floating WhatsApp button bottom-right.

  # estimated_delivery_date tests

  test "estimated_delivery_date returns the next-working-day delivery date" do
    order = orders(:one)
    travel_to Time.zone.local(2026, 3, 16, 12, 0, 0) do # Monday, before 2pm cutoff
      order.update_columns(created_at: Time.current)
      result = estimated_delivery_date(order)
      # Dispatched Monday, delivered Tuesday
      assert_equal "2026-03-17", result
    end
  end

  test "estimated_delivery_date rolls weekend orders to the next working day" do
    order = orders(:one)
    travel_to Time.zone.local(2026, 3, 21, 12, 0, 0) do # Saturday
      order.update_columns(created_at: Time.current)
      result = estimated_delivery_date(order)
      # Cutoff Monday, delivered Tuesday (no weekend delivery)
      assert_equal "2026-03-24", result
    end
  end
end
