module AgenticCommerce
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
