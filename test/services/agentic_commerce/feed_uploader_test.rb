require "test_helper"
require "webmock/minitest"

module AgenticCommerce
  class FeedUploaderTest < ActiveSupport::TestCase
    IMPORTS_URL = "https://api.stripe.com/v2/commerce/product_catalog/imports"
    UPLOAD_URL = "https://stripeusercontent.com/files/us-west-2/upload/wksp_test"
    CSV_BODY = "id,price\nSKU-1,9.99 GBP\n"

    def stub_create_import
      stub_request(:post, IMPORTS_URL)
        .with(
          headers: { "Stripe-Version" => FeedUploader::API_VERSION },
          body: hash_including("feed_type" => "product", "mode" => "upsert")
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "pcimprt_test_123",
            object: "v2.commerce.product_catalog_import",
            feed_type: "product",
            status: "awaiting_upload",
            status_details: {
              awaiting_upload: {
                upload_url: { expires_at: 5.minutes.from_now.iso8601, url: UPLOAD_URL }
              }
            },
            livemode: false
          }.to_json
        )
    end

    test "creates the import, uploads the CSV and records the import" do
      stub_create_import
      upload = stub_request(:put, UPLOAD_URL)
        .with(body: CSV_BODY, headers: { "Content-Type" => "text/csv" })
        .to_return(status: 200)

      import = FeedUploader.new.upload(feed_type: "product", csv: CSV_BODY, row_count: 1)

      assert_requested upload
      assert import.persisted?
      assert_equal "pcimprt_test_123", import.stripe_import_id
      assert_equal "product", import.feed_type
      assert_equal "upsert", import.mode
      assert_equal 1, import.row_count
      assert_equal "processing", import.status
    end

    test "refresh pulls the terminal status and the error rows from Stripe" do
      import = AgenticCommerceImport.create!(
        stripe_import_id: "pcimprt_test_123", feed_type: "product", mode: "upsert", row_count: 3, status: "processing"
      )
      stub_request(:get, "#{IMPORTS_URL}/pcimprt_test_123")
        .with(headers: { "Stripe-Version" => FeedUploader::API_VERSION })
        .to_return(
          status: 200, headers: { "Content-Type" => "application/json" },
          body: {
            id: "pcimprt_test_123", object: "v2.commerce.product_catalog_import", feed_type: "product",
            status: "succeeded_with_errors", livemode: false,
            status_details: {
              succeeded_with_errors: {
                success_count: 2, error_count: 1,
                error_file: { download_url: { expires_at: 5.minutes.from_now.iso8601, url: "https://files.example/errors.csv" } }
              }
            }
          }.to_json
        )
      stub_request(:get, "https://files.example/errors.csv")
        .to_return(status: 200, body: "stripe_error_message,id\nimage_link must be https,SKU-3\n")

      FeedUploader.new.refresh(import)

      assert_equal "succeeded_with_errors", import.reload.status
      assert_equal false, import.livemode
      assert_includes import.error_summary, "image_link must be https"
      assert_includes import.error_summary, "SKU-3"
    end

    test "a rejected upload leaves the import marked as failed and raises" do
      stub_create_import
      stub_request(:put, UPLOAD_URL).to_return(status: 403, body: "expired")

      error = assert_raises(FeedUploader::UploadError) do
        FeedUploader.new.upload(feed_type: "product", csv: CSV_BODY, row_count: 1)
      end

      assert_match(/403/, error.message)
      import = AgenticCommerceImport.find_by!(stripe_import_id: "pcimprt_test_123")
      assert_equal "upload_failed", import.status
    end
  end
end
