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
      results = articles.map { |article_data| process_article(article_data) }

      {
        status: determine_overall_status(results),
        processed: articles.count,
        results: results
      }
    end

    private

    def process_article(article_data)
      result = ArticleImporter.new(article_data).call
      format_result(result)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[Outrank] Failed to import article #{article_data['id']}: #{e.message}"
      {
        outrank_id: article_data["id"],
        status: "error",
        message: e.record.errors.full_messages.join(", ")
      }
    rescue StandardError => e
      Rails.logger.error "[Outrank] Unexpected error importing article #{article_data['id']}: #{e.message}"
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
  end
end
