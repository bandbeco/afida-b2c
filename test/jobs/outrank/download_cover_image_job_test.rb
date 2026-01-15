# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Outrank
  class DownloadCoverImageJobTest < ActiveJob::TestCase
    setup do
      @post = blog_posts(:draft_post)
      @image_url = "https://cdn.outrank.so/cover.jpg"
      @image_content = file_fixture("test_image.jpg").read
    end

    test "downloads and attaches image to blog post" do
      stub_request(:get, @image_url)
        .to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })

      DownloadCoverImageJob.perform_now(@post.id, @image_url)

      @post.reload
      assert @post.cover_image.attached?
    end

    test "discards job silently when blog post not found" do
      non_existent_id = 999_999

      assert_nothing_raised do
        DownloadCoverImageJob.perform_now(non_existent_id, @image_url)
      end
    end

    test "handles download failure gracefully" do
      stub_request(:get, @image_url).to_return(status: 404)

      assert_nothing_raised do
        DownloadCoverImageJob.perform_now(@post.id, @image_url)
      end

      @post.reload
      assert_not @post.cover_image.attached?
    end
  end
end
