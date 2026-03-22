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

  # Renders the Google Merchant store widget (shows store rating badge).
  # Can be placed on any page; typically in the layout.
  def gcr_store_widget
    return "" unless gcr_configured?

    safe_join([
      content_tag(:script, nil,
        id: "merchantWidgetScript",
        src: "https://www.gstatic.com/shopping/merchant/merchantwidget.js",
        defer: "defer"
      ),
      content_tag(:script, %(
merchantWidgetScript.addEventListener('load', function() {
  merchantwidget.start({
    position: 'RIGHT_BOTTOM'
  });
});
      ).html_safe)
    ])
  end

  # Calculates estimated delivery date: 5 business days from order creation.
  def estimated_delivery_date(order)
    date = order.created_at.to_date
    business_days = 0

    while business_days < 5
      date += 1.day
      business_days += 1 unless date.saturday? || date.sunday?
    end

    date.iso8601
  end
end
