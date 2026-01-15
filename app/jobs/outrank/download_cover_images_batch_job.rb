# frozen_string_literal: true

module Outrank
  # Downloads cover images for multiple BlogPosts in a single job.
  #
  # More efficient than individual DownloadCoverImageJob calls when processing
  # webhook batches, as it reduces job queue overhead and allows for potential
  # connection pooling optimizations.
  #
  # Usage:
  #   Outrank::DownloadCoverImagesBatchJob.perform_later([
  #     { blog_post_id: 1, image_url: "https://..." },
  #     { blog_post_id: 2, image_url: "https://..." }
  #   ])
  #
  class DownloadCoverImagesBatchJob < ApplicationJob
    queue_as :default

    def perform(image_downloads)
      image_downloads.each do |download|
        blog_post_id = download[:blog_post_id] || download["blog_post_id"]
        image_url = download[:image_url] || download["image_url"]

        download_image(blog_post_id, image_url)
      end
    end

    private

    def download_image(blog_post_id, image_url)
      blog_post = BlogPost.find_by(id: blog_post_id)
      return if blog_post.nil?

      Outrank::ImageDownloader.new(blog_post, image_url).call
    rescue StandardError => e
      # Log but don't fail the whole batch for one bad image
      Rails.logger.warn "[Outrank] Batch image download failed for BlogPost##{blog_post_id}: #{e.message}"
    end
  end
end
