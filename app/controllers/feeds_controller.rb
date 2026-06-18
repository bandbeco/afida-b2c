class FeedsController < ApplicationController
  allow_unauthenticated_access
  # Crawler-only XML endpoint: no visitor to attribute, so don't emit a tracking cookie.
  skip_before_action :ensure_datafast_visitor_id

  def google_merchant
    @products = Product.includes(:category).with_attached_product_photo.with_attached_lifestyle_photo.active

    feed_generator = GoogleMerchantFeedGenerator.new(@products)

    respond_to do |format|
      format.xml { render xml: feed_generator.generate_xml }
    end
  end
end
