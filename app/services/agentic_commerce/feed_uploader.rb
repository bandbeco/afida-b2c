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

    # Pulls the import's current state from Stripe onto the record. On
    # succeeded_with_errors the error CSV (only the failed rows, each with a
    # stripe_error_message) is fetched inside its five-minute window and kept
    # on the record, truncated, so it can be read after the URL has expired.
    def refresh(import)
      stripe_import = client.v2.commerce.product_catalog.imports.retrieve(
        import.stripe_import_id, {}, { stripe_version: API_VERSION }
      )
      attributes = { status: stripe_import.status, livemode: stripe_import.livemode }
      attributes[:error_summary] = error_summary_for(stripe_import) if import.status != stripe_import.status
      import.update!(attributes.compact)
      import
    end

    private

    attr_reader :client

    ERROR_SUMMARY_LIMIT = 20_000

    def error_summary_for(stripe_import)
      details = stripe_import.status_details
      case stripe_import.status
      when "succeeded_with_errors"
        url = details.succeeded_with_errors.error_file&.download_url&.url
        return "#{details.succeeded_with_errors.error_count} rows failed (no error file)" if url.blank?

        response = HTTP.timeout(UPLOAD_TIMEOUT_SECONDS).get(url)
        response.status.success? ? response.body.to_s.first(ERROR_SUMMARY_LIMIT) : "error file fetch failed: HTTP #{response.status}"
      when "failed"
        [ details.failed.code, details.failed.failure_message ].compact.join(": ")
      end
    end

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
