require "test_helper"
require "webmock/minitest"

module AgenticCommerce
  class PushProductFeedJobTest < ActiveJob::TestCase
    IMPORTS_URL = "https://api.stripe.com/v2/commerce/product_catalog/imports"
    UPLOAD_URL = "https://stripeusercontent.com/files/us-west-2/upload/wksp_job"

    setup do
      Rails.application.routes.default_url_options[:host] = "example.com"
      Rails.application.routes.default_url_options[:protocol] = "https"
      stub_request(:post, IMPORTS_URL).to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "pcimprt_job_1", object: "v2.commerce.product_catalog_import", feed_type: "product",
          status: "awaiting_upload",
          status_details: { awaiting_upload: { upload_url: { expires_at: 5.minutes.from_now.iso8601, url: UPLOAD_URL } } },
          livemode: false
        }.to_json
      )
    end

    test "pushes the eligible catalogue as an upsert product feed and records the SKUs sent" do
      product = products(:one)
      product.product_photo.attach(io: file_fixture("test_image.jpg").open, filename: "p.jpg", content_type: "image/jpeg")
      upload = stub_request(:put, UPLOAD_URL).with { |request| request.body.include?(product.sku) }.to_return(status: 200)

      PushProductFeedJob.perform_now

      assert_requested upload
      import = AgenticCommerceImport.find_by!(stripe_import_id: "pcimprt_job_1")
      assert_equal "product", import.feed_type
      assert_equal "upsert", import.mode
      assert_equal "processing", import.status
      assert_equal 1, import.row_count
      assert_equal [ product.sku ], import.skus
    end
  end
end
