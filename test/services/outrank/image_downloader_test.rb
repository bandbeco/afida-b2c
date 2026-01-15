# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Outrank
  class ImageDownloaderTest < ActiveSupport::TestCase
    setup do
      @post = blog_posts(:draft_post)
    end

    # ==========================================================================
    # T5.1: Downloads and attaches cover image
    # ==========================================================================

    test "downloads and attaches image" do
      image_url = "https://example.com/images/cover.jpg"
      image_content = file_fixture("test_image.jpg").read

      stub_request(:get, image_url)
        .to_return(
          body: image_content,
          headers: { "Content-Type" => "image/jpeg" }
        )

      Outrank::ImageDownloader.new(@post, image_url).call

      assert @post.cover_image.attached?
      assert_equal "cover.jpg", @post.cover_image.filename.to_s
    end

    test "extracts filename from URL path" do
      image_url = "https://cdn.outrank.so/uploads/2026/01/eco-packaging-hero.png"
      image_content = file_fixture("test_image.jpg").read

      stub_request(:get, image_url)
        .to_return(
          body: image_content,
          headers: { "Content-Type" => "image/png" }
        )

      Outrank::ImageDownloader.new(@post, image_url).call

      assert_equal "eco-packaging-hero.png", @post.cover_image.filename.to_s
    end

    # ==========================================================================
    # T5.2: Handles missing image gracefully
    # ==========================================================================

    test "handles nil image_url gracefully" do
      assert_nothing_raised do
        result = Outrank::ImageDownloader.new(@post, nil).call
        assert_equal false, result
      end

      assert_not @post.cover_image.attached?
    end

    test "handles blank image_url gracefully" do
      assert_nothing_raised do
        result = Outrank::ImageDownloader.new(@post, "").call
        assert_equal false, result
      end

      assert_not @post.cover_image.attached?
    end

    # ==========================================================================
    # T5.3: Handles failed downloads gracefully
    # ==========================================================================

    test "handles 404 error gracefully" do
      image_url = "https://example.com/missing.jpg"

      stub_request(:get, image_url).to_return(status: 404)

      assert_nothing_raised do
        result = Outrank::ImageDownloader.new(@post, image_url).call
        assert_equal false, result
      end

      assert_not @post.cover_image.attached?
    end

    test "handles 500 error gracefully" do
      image_url = "https://example.com/error.jpg"

      stub_request(:get, image_url).to_return(status: 500)

      assert_nothing_raised do
        Outrank::ImageDownloader.new(@post, image_url).call
      end

      assert_not @post.cover_image.attached?
    end

    test "handles network timeout gracefully" do
      image_url = "https://example.com/slow.jpg"

      stub_request(:get, image_url).to_timeout

      assert_nothing_raised do
        Outrank::ImageDownloader.new(@post, image_url).call
      end

      assert_not @post.cover_image.attached?
    end

    test "handles connection refused gracefully" do
      image_url = "https://example.com/unreachable.jpg"

      stub_request(:get, image_url).to_raise(HTTP::ConnectionError)

      assert_nothing_raised do
        Outrank::ImageDownloader.new(@post, image_url).call
      end

      assert_not @post.cover_image.attached?
    end

    test "logs error when download fails" do
      image_url = "https://example.com/broken.jpg"

      stub_request(:get, image_url).to_return(status: 404)
      Rails.logger.expects(:warn).with(includes("Failed to download"))

      Outrank::ImageDownloader.new(@post, image_url).call
    end

    test "handles invalid URL gracefully" do
      assert_nothing_raised do
        Outrank::ImageDownloader.new(@post, "not-a-valid-url").call
      end

      assert_not @post.cover_image.attached?
    end
  end
end
