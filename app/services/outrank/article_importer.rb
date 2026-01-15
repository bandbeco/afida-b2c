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
  class ArticleImporter
    def initialize(article_data)
      @article_data = article_data
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

      BlogPost.create!(
        outrank_id: @article_data["id"],
        title: @article_data["title"],
        slug: slug,
        body: sanitize_content(@article_data["content_markdown"]),
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
      raise e if @slug_retry_count.to_i >= 5  # Prevent infinite retries

      @slug_retry_count = @slug_retry_count.to_i + 1
      Rails.logger.info "[Outrank] Slug collision detected, retrying (attempt #{@slug_retry_count})"
      retry
    end

    def enqueue_cover_image_download(blog_post)
      image_url = @article_data["image_url"]
      return if image_url.blank?

      # Download asynchronously to avoid blocking webhook response
      DownloadCoverImageJob.perform_later(blog_post.id, image_url)
    end

    def find_or_create_category
      tags = @article_data["tags"]
      return nil if tags.blank?

      category_name = tags.first
      return nil if category_name.blank?

      BlogCategory.find_or_create_by!(name: category_name) do |cat|
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
      plain_text.truncate(160)
    end

    def sanitize_content(content)
      return "" if content.blank?

      # Use Loofah directly to strip dangerous tags AND their contents.
      # Rails.html_sanitizer.sanitize only removes tags, leaving content visible.
      # Loofah's :prune scrubber removes both tag and content for unsafe elements.
      doc = Loofah.fragment(content)

      # First, completely remove dangerous elements and their contents
      doc.scrub!(:prune)

      # Then apply whitelist to keep only safe formatting elements
      # Note: img/src excluded to prevent javascript: and data: URI XSS attacks
      ActionController::Base.helpers.sanitize(
        doc.to_s,
        tags: %w[h1 h2 h3 h4 h5 h6 p a em strong ul ol li blockquote code pre br hr],
        attributes: %w[href alt title class]
      )
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
        raise "Could not generate unique slug after 100 attempts" if counter > 100
      end
    end
  end
end
