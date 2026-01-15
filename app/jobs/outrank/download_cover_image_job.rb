# frozen_string_literal: true

module Outrank
  # Downloads and attaches a cover image to a BlogPost in the background.
  #
  # This job is enqueued by ArticleImporter when an article has an image_url.
  # Running in the background ensures webhook responses are fast and don't
  # block on external HTTP requests.
  #
  # Usage:
  #   Outrank::DownloadCoverImageJob.perform_later(blog_post_id, image_url)
  #
  class DownloadCoverImageJob < ApplicationJob
    queue_as :default

    # If blog post is deleted before job runs, just discard silently
    discard_on ActiveRecord::RecordNotFound

    def perform(blog_post_id, image_url)
      blog_post = BlogPost.find(blog_post_id)
      Outrank::ImageDownloader.new(blog_post, image_url).call
    end
  end
end
