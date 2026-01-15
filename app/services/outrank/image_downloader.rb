# frozen_string_literal: true

require "http"

module Outrank
  # Downloads a cover image from URL and attaches it to a BlogPost via Active Storage.
  #
  # Handles all failure scenarios gracefully - a failed download should never
  # prevent article creation. Errors are logged for debugging.
  #
  # Usage:
  #   Outrank::ImageDownloader.new(blog_post, "https://example.com/image.jpg").call
  #   # => true if attached successfully
  #   # => false if download failed or URL blank
  #
  class ImageDownloader
    TIMEOUT_SECONDS = 10
    MAX_FILE_SIZE = 10.megabytes

    def initialize(blog_post, image_url)
      @blog_post = blog_post
      @image_url = image_url
    end

    def call
      return false if @image_url.blank?

      download_and_attach
    rescue HTTP::Error, HTTP::TimeoutError => e
      log_error("HTTP error: #{e.message}")
      false
    rescue URI::InvalidURIError => e
      log_error("Invalid URL: #{e.message}")
      false
    rescue StandardError => e
      log_error("Unexpected error: #{e.message}")
      false
    end

    private

    def download_and_attach
      response = HTTP.timeout(TIMEOUT_SECONDS).get(@image_url)

      unless response.status.success?
        log_error("HTTP #{response.status} response")
        return false
      end

      body = response.body.to_s

      if body.bytesize > MAX_FILE_SIZE
        log_error("File too large (#{body.bytesize} bytes)")
        return false
      end

      # Handle missing Content-Type header gracefully
      content_type = response.content_type&.mime_type || "application/octet-stream"
      attach_image(body, content_type)
      true
    end

    def attach_image(body, content_type)
      filename = extract_filename
      io = StringIO.new(body)

      @blog_post.cover_image.attach(
        io: io,
        filename: filename,
        content_type: content_type
      )
    end

    def extract_filename
      uri = URI.parse(@image_url)
      File.basename(uri.path).presence || "cover-image.jpg"
    rescue URI::InvalidURIError
      "cover-image.jpg"
    end

    def log_error(message)
      Rails.logger.warn "[Outrank] Failed to download cover image for BlogPost##{@blog_post.id}: #{message}"
    end
  end
end
