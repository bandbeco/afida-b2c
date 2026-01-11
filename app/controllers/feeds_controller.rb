class FeedsController < ApplicationController
  allow_unauthenticated_access

  def google_merchant
    @products = Product.includes(:category).with_attached_product_photo

    feed_generator = GoogleMerchantFeedGenerator.new(@products)

    respond_to do |format|
      format.xml { render xml: feed_generator.generate_xml }
    end
  end
end
