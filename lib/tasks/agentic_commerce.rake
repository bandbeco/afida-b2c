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

  desc "Refresh the status of every non-terminal Stripe import (or one: agentic_commerce:refresh_imports[pcimprt_...])"
  task :refresh_imports, [ :stripe_import_id ] => :environment do |_task, args|
    scope = AgenticCommerceImport.all
    scope = if args[:stripe_import_id].present?
      scope.where(stripe_import_id: args[:stripe_import_id])
    else
      scope.where(status: %w[awaiting_upload processing])
    end
    uploader = AgenticCommerce::FeedUploader.new
    scope.find_each do |import|
      uploader.refresh(import)
      puts "#{import.stripe_import_id} #{import.feed_type} livemode=#{import.livemode.inspect} #{import.row_count} rows: #{import.status}"
      puts import.error_summary if import.error_summary.present?
    end
  end
end
