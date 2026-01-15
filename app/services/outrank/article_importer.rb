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
      download_cover_image(blog_post)
      Rails.logger.info "[Outrank] Created blog post #{blog_post.id} from article: #{outrank_id}"

      { status: :created, outrank_id: outrank_id, blog_post_id: blog_post.id }
    end

    private

    def create_blog_post
      BlogPost.create!(
        outrank_id: @article_data["id"],
        title: @article_data["title"],
        slug: @article_data["slug"],
        body: sanitize_content(@article_data["content_markdown"]),
        excerpt: extract_excerpt(@article_data["content_markdown"]),
        meta_title: @article_data["title"],
        meta_description: @article_data["meta_description"],
        blog_category: find_or_create_category,
        published: false,
        published_at: nil
      )
    end

    def download_cover_image(blog_post)
      image_url = @article_data["image_url"]
      return if image_url.blank?

      ImageDownloader.new(blog_post, image_url).call
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

      # First, completely strip dangerous tags and their contents
      # Rails.html_sanitizer doesn't strip content inside script/style, so we do it manually
      safe_content = content.dup
      safe_content.gsub!(/<script\b[^>]*>.*?<\/script>/mi, "")
      safe_content.gsub!(/<style\b[^>]*>.*?<\/style>/mi, "")
      safe_content.gsub!(/<iframe\b[^>]*>.*?<\/iframe>/mi, "")
      safe_content.gsub!(/<iframe\b[^>]*\/>/mi, "")
      safe_content.gsub!(/<object\b[^>]*>.*?<\/object>/mi, "")
      safe_content.gsub!(/<embed\b[^>]*\/?>/mi, "")

      # Then sanitize remaining HTML, keeping safe formatting tags
      ActionController::Base.helpers.sanitize(
        safe_content,
        tags: %w[h1 h2 h3 h4 h5 h6 p a em strong ul ol li blockquote code pre img br hr],
        attributes: %w[href src alt title class]
      )
    end
  end
end
