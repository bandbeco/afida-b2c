module AgenticCommerce
  # Daily full push of the stock catalogue to Stripe Agentic Commerce Suite
  # (see config/recurring.yml). Always an upsert: products missing from the
  # file are left alone on Stripe's side, so a partial render can never wipe
  # the catalogue. Deletions are sent explicitly (Phase 3 of the plan).
  class PushProductFeedJob < ApplicationJob
    queue_as :default

    def perform
      feed = ProductFeed.new
      FeedUploader.new.upload(
        feed_type: "product",
        csv: feed.to_csv,
        row_count: feed.row_count,
        skus: feed.skus
      )
    end
  end
end
