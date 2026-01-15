# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Outrank
  class DownloadCoverImagesBatchJobTest < ActiveJob::TestCase
    setup do
      @post1 = blog_posts(:draft_post)
      @post2 = blog_posts(:published_post)
      @image_content = file_fixture("test_image.jpg").read
    end

    test "downloads multiple images in a single job" do
      url1 = "https://cdn.outrank.so/image1.jpg"
      url2 = "https://cdn.outrank.so/image2.jpg"

      stub_request(:get, url1).to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })
      stub_request(:get, url2).to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })

      DownloadCoverImagesBatchJob.perform_now([
        { blog_post_id: @post1.id, image_url: url1 },
        { blog_post_id: @post2.id, image_url: url2 }
      ])

      @post1.reload
      @post2.reload

      assert @post1.cover_image.attached?
      assert @post2.cover_image.attached?
    end

    test "continues processing when one image fails" do
      url1 = "https://cdn.outrank.so/broken.jpg"
      url2 = "https://cdn.outrank.so/good.jpg"

      stub_request(:get, url1).to_return(status: 404)
      stub_request(:get, url2).to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })

      # Should not raise error
      assert_nothing_raised do
        DownloadCoverImagesBatchJob.perform_now([
          { blog_post_id: @post1.id, image_url: url1 },
          { blog_post_id: @post2.id, image_url: url2 }
        ])
      end

      @post1.reload
      @post2.reload

      assert_not @post1.cover_image.attached?
      assert @post2.cover_image.attached?
    end

    test "handles missing blog post gracefully" do
      url = "https://cdn.outrank.so/image.jpg"
      stub_request(:get, url).to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })

      assert_nothing_raised do
        DownloadCoverImagesBatchJob.perform_now([
          { blog_post_id: 999_999, image_url: url },
          { blog_post_id: @post1.id, image_url: url }
        ])
      end

      @post1.reload
      assert @post1.cover_image.attached?
    end

    test "accepts string keys in hash" do
      url = "https://cdn.outrank.so/image.jpg"
      stub_request(:get, url).to_return(body: @image_content, headers: { "Content-Type" => "image/jpeg" })

      DownloadCoverImagesBatchJob.perform_now([
        { "blog_post_id" => @post1.id, "image_url" => url }
      ])

      @post1.reload
      assert @post1.cover_image.attached?
    end
  end
end
