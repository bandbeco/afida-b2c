namespace :agentic_commerce do
  desc "Push the stock catalogue to Stripe Agentic Commerce Suite now (same as the daily job)"
  task push_product_feed: :environment do
    import = AgenticCommerce::PushProductFeedJob.perform_now
    puts "#{import.feed_type} feed #{import.stripe_import_id}: #{import.row_count} rows, status #{import.status}"
  end

  desc "Write the Agentic Commerce product feed CSV to stdout without uploading"
  task preview_product_feed: :environment do
    puts AgenticCommerce::ProductFeed.new.to_csv
  end
end
