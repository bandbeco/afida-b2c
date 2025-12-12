namespace :object_storage do
  desc "Delete all objects from Hetzner Object Storage bucket"
  task purge: :environment do
    require "aws-sdk-s3"

    bucket_name = "afida-b2c"
    endpoint = "https://nbg1.your-objectstorage.com"

    credentials = Rails.application.credentials.dig(:hetzner)
    unless credentials&.dig(:access_key) && credentials&.dig(:secret_key)
      puts "❌ Missing Hetzner credentials in Rails credentials"
      puts "   Run: rails credentials:edit"
      puts "   Add:"
      puts "     hetzner:"
      puts "       access_key: YOUR_ACCESS_KEY"
      puts "       secret_key: YOUR_SECRET_KEY"
      exit 1
    end

    client = Aws::S3::Client.new(
      endpoint: endpoint,
      access_key_id: credentials[:access_key],
      secret_access_key: credentials[:secret_key],
      region: "us-east-1", # Required by SDK but ignored by Hetzner
      force_path_style: true # Required for S3-compatible endpoints
    )

    puts "🗂️  Connecting to Hetzner Object Storage..."
    puts "   Endpoint: #{endpoint}"
    puts "   Bucket: #{bucket_name}"
    puts

    # Count objects first
    total_objects = 0
    total_size = 0
    client.list_objects_v2(bucket: bucket_name).each do |response|
      response.contents.each do |object|
        total_objects += 1
        total_size += object.size
      end
    end

    if total_objects == 0
      puts "✅ Bucket is already empty"
      exit 0
    end

    size_mb = (total_size / 1024.0 / 1024.0).round(2)
    puts "📊 Found #{total_objects} objects (#{size_mb} MB)"
    puts

    # Require explicit confirmation
    puts "⚠️  WARNING: This will permanently delete ALL objects!"
    print "   Type 'DELETE ALL' to confirm: "
    confirmation = $stdin.gets&.strip

    unless confirmation == "DELETE ALL"
      puts "❌ Aborted. No objects were deleted."
      exit 1
    end

    puts
    puts "🗑️  Deleting objects..."

    deleted_count = 0
    errors = []

    # Delete in batches of 1000 (S3 API limit)
    client.list_objects_v2(bucket: bucket_name).each do |response|
      next if response.contents.empty?

      objects_to_delete = response.contents.map { |obj| { key: obj.key } }

      begin
        result = client.delete_objects(
          bucket: bucket_name,
          delete: { objects: objects_to_delete, quiet: false }
        )

        deleted_count += result.deleted.size
        errors.concat(result.errors) if result.errors.any?

        print "\r   Deleted: #{deleted_count}/#{total_objects}"
      rescue Aws::S3::Errors::ServiceError => e
        errors << { key: "batch", message: e.message }
      end
    end

    puts
    puts

    if errors.any?
      puts "⚠️  Completed with #{errors.size} errors:"
      errors.first(10).each do |err|
        puts "   - #{err[:key]}: #{err[:message] || err.message}"
      end
      puts "   ... and #{errors.size - 10} more" if errors.size > 10
    else
      puts "✅ Successfully deleted #{deleted_count} objects"
    end
  end

  desc "List objects in Hetzner Object Storage bucket"
  task list: :environment do
    require "aws-sdk-s3"

    bucket_name = "afida-b2c"
    endpoint = "https://nbg1.your-objectstorage.com"

    credentials = Rails.application.credentials.dig(:hetzner)
    unless credentials&.dig(:access_key) && credentials&.dig(:secret_key)
      puts "❌ Missing Hetzner credentials"
      exit 1
    end

    client = Aws::S3::Client.new(
      endpoint: endpoint,
      access_key_id: credentials[:access_key],
      secret_access_key: credentials[:secret_key],
      region: "us-east-1",
      force_path_style: true
    )

    puts "📦 Objects in #{bucket_name}:"
    puts

    total_objects = 0
    total_size = 0

    client.list_objects_v2(bucket: bucket_name).each do |response|
      response.contents.each do |object|
        size_kb = (object.size / 1024.0).round(2)
        puts "   #{object.key} (#{size_kb} KB)"
        total_objects += 1
        total_size += object.size
      end
    end

    puts
    size_mb = (total_size / 1024.0 / 1024.0).round(2)
    puts "📊 Total: #{total_objects} objects (#{size_mb} MB)"
  end
end
