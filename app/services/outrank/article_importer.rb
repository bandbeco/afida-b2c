# frozen_string_literal: true

module Outrank
  # Imports a single article from Outrank webhook data into a BlogPost.
  #
  # Creates a draft BlogPost with mapped fields, assigns category from first tag,
  # and extracts excerpt from content. Returns a result hash with status.
  #
  # Usage:
  #   result = Outrank::ArticleImporter.new(article_data).call
  #   # => { status: :created, outrank_id: "abc123", blog_post_id: 42 }
  #   # => { status: :skipped, outrank_id: "abc123", reason: "duplicate" }
  #
  # Options:
  #   category_cache: Hash of { name => BlogCategory } to avoid N+1 queries in batch
  #
  class ArticleImporter
    # Maximum excerpt length for SEO-friendly summaries
    EXCERPT_MAX_LENGTH = 160

    # Maximum attempts to generate a unique slug before giving up
    MAX_SLUG_ATTEMPTS = 100

    # Maximum retries for race condition on slug uniqueness constraint
    MAX_SLUG_RETRIES = 5

    def initialize(article_data, category_cache: {}, image_downloads: nil)
      @article_data = article_data
      @category_cache = category_cache
      @image_downloads = image_downloads  # nil means use individual jobs
    end

    def call
      outrank_id = @article_data["id"]

      # Check for duplicate (idempotency)
      if BlogPost.exists?(outrank_id: outrank_id)
        Rails.logger.info "[Outrank] Skipping duplicate article: #{outrank_id}"
        return { status: :skipped, outrank_id: outrank_id, reason: "duplicate" }
      end

      blog_post = create_blog_post
      enqueue_cover_image_download(blog_post)
      Rails.logger.info "[Outrank] Created blog post #{blog_post.id} from article: #{outrank_id}"

      { status: :created, outrank_id: outrank_id, blog_post_id: blog_post.id }
    end

    private

    def create_blog_post
      slug = generate_unique_slug(@article_data["slug"])

      # NOTE: Content is stored as-is. XSS protection happens at RENDER TIME
      # in article_helper.rb, not here. See that file for the sanitization pipeline.
      BlogPost.create!(
        outrank_id: @article_data["id"],
        title: @article_data["title"],
        slug: slug,
        body: @article_data["content_markdown"].to_s,
        excerpt: extract_excerpt(@article_data["content_markdown"]),
        meta_title: @article_data["title"],
        meta_description: @article_data["meta_description"],
        blog_category: find_or_create_category,
        published: false,
        published_at: nil
      )
    rescue ActiveRecord::RecordNotUnique => e
      # Race condition: another request created a post with our slug between check and create.
      # Retry with incremented counter. The retry will find a new unique slug.
      raise e if @slug_retry_count.to_i >= MAX_SLUG_RETRIES

      @slug_retry_count = @slug_retry_count.to_i + 1
      Rails.logger.info "[Outrank] Slug collision detected, retrying (attempt #{@slug_retry_count})"
      retry
    end

    def enqueue_cover_image_download(blog_post)
      image_url = @article_data["image_url"]
      return if image_url.blank?

      # If batch collection provided, add to it for batch processing
      # Otherwise, enqueue individual job (for single-article imports)
      if @image_downloads
        @image_downloads << { blog_post_id: blog_post.id, image_url: image_url }
      else
        DownloadCoverImageJob.perform_later(blog_post.id, image_url)
      end
    end

    def find_or_create_category
      tags = @article_data["tags"]
      return nil if tags.blank?

      category_name = tags.first
      return nil if category_name.blank?

      # Use cached category if available (avoids N+1 in batch processing)
      # Otherwise, find or create (for single-article imports or new categories)
      @category_cache[category_name] || BlogCategory.find_or_create_by!(name: category_name) do |cat|
        cat.slug = category_name.parameterize
      end
    end

    def extract_excerpt(content_markdown)
      return nil if content_markdown.blank?

      # Find first non-empty paragraph (skip headings starting with #)
      paragraphs = content_markdown.split(/\n\n+/)
      first_para = paragraphs.find { |p| p.present? && !p.strip.start_with?("#") }

      return nil if first_para.blank?

      # Strip markdown formatting and truncate
      plain_text = first_para.gsub(/[#*_\[\]()>`]/, "").strip
      plain_text.truncate(EXCERPT_MAX_LENGTH)
    end

    # Generates a unique slug by appending -2, -3, etc. if collision detected.
    # Handles edge case where Outrank might send different articles with same slug.
    # Note: This is a best-effort check; create_blog_post handles race conditions via retry.
    def generate_unique_slug(base_slug)
      return base_slug unless BlogPost.exists?(slug: base_slug)

      counter = 2
      loop do
        candidate = "#{base_slug}-#{counter}"
        return candidate unless BlogPost.exists?(slug: candidate)

        counter += 1
        # Safety limit to prevent infinite loop (extremely unlikely scenario)
        raise "Could not generate unique slug after #{MAX_SLUG_ATTEMPTS} attempts" if counter > MAX_SLUG_ATTEMPTS
      end
    end
  end
end
