require "http"

module AgenticCommerce
  # Pushes one CSV feed to Stripe Agentic Commerce Suite: creates a
  # ProductCatalogImport, then PUTs the file to the presigned URL Stripe hands
  # back (valid for five minutes). Every attempt is recorded as an
  # AgenticCommerceImport so failures are visible and later pushes can diff.
  class FeedUploader
    # Stripe documents the v2 imports endpoint under this preview version; the
    # app-wide pin stays on the checkout version, so it is passed per call.
    API_VERSION = "2026-08-26.preview"
    UPLOAD_TIMEOUT_SECONDS = 120

    class UploadError < StandardError; end

    def initialize(client: Stripe::StripeClient.new(Stripe.api_key))
      @client = client
    end

    # @return [AgenticCommerceImport] the recorded import, in `processing`
    # @raise [UploadError] when Stripe refuses the file; the record is left
    #   as `upload_failed`
    def upload(feed_type:, csv:, row_count:, mode: "upsert", skus: [])
      stripe_import = create_import(feed_type, mode)
      import = AgenticCommerceImport.create!(
        stripe_import_id: stripe_import.id,
        feed_type: feed_type,
        mode: mode,
        row_count: row_count,
        skus: skus,
        status: "awaiting_upload"
      )

      response = put_csv(stripe_import.status_details.awaiting_upload.upload_url.url, csv)
      unless response.status.success?
        summary = "HTTP #{response.status}: #{response.body.to_s.first(500)}"
        import.update!(status: "upload_failed", error_summary: summary)
        raise UploadError, "Stripe rejected #{feed_type} feed upload for #{import.stripe_import_id}: #{summary}"
      end

      import.update!(status: "processing")
      import
    end

    private

    attr_reader :client

    def create_import(feed_type, mode)
      client.v2.commerce.product_catalog.imports.create(
        { feed_type: feed_type, mode: mode, metadata: { file_name: file_name(feed_type) } },
        { stripe_version: API_VERSION }
      )
    end

    def put_csv(url, csv)
      HTTP.timeout(UPLOAD_TIMEOUT_SECONDS).put(url, body: csv, headers: { "Content-Type" => "text/csv" })
    end

    def file_name(feed_type)
      "afida_#{feed_type}_#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}.csv"
    end
  end
end
