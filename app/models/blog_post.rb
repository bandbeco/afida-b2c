# frozen_string_literal: true

# Represents a blog post with Markdown content.
#
# Blog posts are public-facing content for SEO, company news, and educational resources.
# Content is stored as Markdown and rendered to HTML for display.
#
# Key features:
# - Slug-based URLs for SEO (e.g., /blog/eco-friendly-packaging-guide)
# - Simple published/draft status with automatic published_at timestamp
# - SEO fields with fallback to title/excerpt
# - Cover image for visual appeal on index pages
#
class BlogPost < ApplicationRecord
  # ==========================================================================
  # Attachments
  # ==========================================================================

  has_one_attached :cover_image

  # ==========================================================================
  # Validations
  # ==========================================================================

  validates :title, presence: true
  validates :body, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  # ==========================================================================
  # Callbacks
  # ==========================================================================

  before_validation :generate_slug
  before_save :set_published_at

  # ==========================================================================
  # Scopes
  # ==========================================================================

  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: false) }
  scope :recent, -> { order(published_at: :desc) }

  # ==========================================================================
  # Instance Methods
  # ==========================================================================

  # URL generation uses slug instead of ID
  def to_param
    slug
  end

  # Returns excerpt if present, otherwise truncates body (stripped of Markdown)
  def excerpt_with_fallback
    return excerpt if excerpt.present?

    # Strip Markdown formatting and truncate
    plain_text = body.gsub(/[#*_\[\]()>`]/, "").gsub(/\n+/, " ").strip
    plain_text.truncate(160)
  end

  # Returns meta_title if present, otherwise falls back to title
  def meta_title_with_fallback
    meta_title.presence || title
  end

  # Returns meta_description if present, otherwise falls back to excerpt
  def meta_description_with_fallback
    meta_description.presence || excerpt_with_fallback
  end

  private

  # Generates URL-friendly slug from title if not already set
  def generate_slug
    return if slug.present? || title.blank?

    self.slug = title.parameterize
  end

  # Sets published_at timestamp when first published
  def set_published_at
    return unless published_changed? && published? && published_at.nil?

    self.published_at = Time.current
  end
end
