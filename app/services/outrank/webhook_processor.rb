# frozen_string_literal: true

module Outrank
  # Processes webhook payloads from Outrank, orchestrating batch article imports.
  #
  # Iterates over articles in the payload, delegates each to ArticleImporter,
  # and aggregates results. Continues processing even if individual articles fail.
  #
  # Usage:
  #   result = Outrank::WebhookProcessor.new(payload).call
  #   # => {
  #   #      status: "success",
  #   #      processed: 3,
  #   #      results: [
  #   #        { outrank_id: "abc", status: "created", blog_post_id: 42 },
  #   #        { outrank_id: "def", status: "skipped", reason: "duplicate" },
  #   #        { outrank_id: "ghi", status: "error", message: "..." }
  #   #      ]
  #   #    }
  #
  class WebhookProcessor
    def initialize(payload)
      @payload = payload
    end

    def call
      articles = @payload.dig("data", "articles") || []

      # Preload all categories that might be referenced to avoid N+1 queries
      @category_cache = preload_categories(articles)
      @image_downloads = []

      results = articles.map { |article_data| process_article(article_data) }

      # Enqueue batch image download job if there are any images to download
      enqueue_batch_image_downloads

      {
        status: determine_overall_status(results),
        processed: articles.count,
        results: results
      }
    end

    private

    def process_article(article_data)
      result = ArticleImporter.new(article_data, category_cache: @category_cache, image_downloads: @image_downloads).call
      format_result(result)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[Outrank] Failed to import article #{article_data['id']}: #{e.message}"
      report_error(e, article_data)
      {
        outrank_id: article_data["id"],
        status: "error",
        message: e.record.errors.full_messages.join(", ")
      }
    rescue StandardError => e
      Rails.logger.error "[Outrank] Unexpected error importing article #{article_data['id']}: #{e.message}"
      report_error(e, article_data)
      {
        outrank_id: article_data["id"],
        status: "error",
        message: e.message
      }
    end

    def format_result(result)
      formatted = {
        outrank_id: result[:outrank_id],
        status: result[:status].to_s
      }

      formatted[:blog_post_id] = result[:blog_post_id] if result[:blog_post_id]
      formatted[:reason] = result[:reason] if result[:reason]

      formatted
    end

    def determine_overall_status(results)
      return "success" if results.empty?

      has_errors = results.any? { |r| r[:status] == "error" }
      has_errors ? "partial" : "success"
    end

    # Preloads all BlogCategories that match any article's first tag.
    # Returns a hash of { category_name => BlogCategory } for O(1) lookups.
    # This avoids N+1 queries when processing multiple articles.
    def preload_categories(articles)
      category_names = articles
        .map { |a| a["tags"]&.first }
        .compact
        .uniq

      return {} if category_names.empty?

      BlogCategory.where(name: category_names).index_by(&:name)
    end

    # Reports errors to Sentry for monitoring and alerting.
    # Includes article context to aid debugging.
    def report_error(error, article_data)
      Sentry.capture_exception(error, extra: {
        outrank_id: article_data["id"],
        article_title: article_data["title"],
        article_slug: article_data["slug"]
      })
    end

    # Enqueues a single batch job for all image downloads.
    # More efficient than individual jobs when processing multiple articles.
    def enqueue_batch_image_downloads
      return if @image_downloads.empty?

      DownloadCoverImagesBatchJob.perform_later(@image_downloads)
    end
  end
end
