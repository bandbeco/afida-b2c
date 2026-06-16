module GoogleCustomerReviewsHelper
  def gcr_merchant_id
    @gcr_merchant_id = Rails.application.credentials.dig(:google_customer_reviews, :merchant_id) if @gcr_merchant_id.nil? && !defined?(@gcr_merchant_id_loaded)
    @gcr_merchant_id_loaded = true
    @gcr_merchant_id
  end

  def gcr_configured?
    gcr_merchant_id.present?
  end

  # Renders the GCR survey opt-in module for the order confirmation page.
  # Google sends the customer a review survey after the estimated delivery date.
  def gcr_survey_opt_in(order)
    return "" unless gcr_configured?

    delivery_date = estimated_delivery_date(order)
    country_code = order.shipping_country.presence || "GB"

    content_tag(:div, id: "gcr-survey") do
      safe_join([
        content_tag(:script, nil,
          src: "https://apis.google.com/js/platform.js?onload=renderOptIn",
          async: "async",
          defer: "defer"
        ),
        content_tag(:script, %(
window.renderOptIn = function() {
  window.gapi.load('surveyoptin', function() {
    window.gapi.surveyoptin.render({
      "merchant_id": #{gcr_merchant_id},
      "order_id": "#{j(order.order_number)}",
      "email": "#{j(order.email)}",
      "delivery_country": "#{j(country_code)}",
      "estimated_delivery_date": "#{delivery_date}",
      "opt_in_style": "BOTTOM_RIGHT_DIALOG"
    });
  });
}
        ).html_safe),
        content_tag(:script, %(
window.___gcfg = {
  lang: 'en-GB'
};
        ).html_safe)
      ])
    end
  end

  # Estimated delivery date for the order, as the next-working-day promise
  # shown elsewhere on the site. Reads the date stamped on the order at purchase
  # (falling back to a computed date for legacy orders). Returns ISO8601 (what
  # GCR's opt-in expects).
  def estimated_delivery_date(order)
    order.estimated_delivery_date.iso8601
  end
end
