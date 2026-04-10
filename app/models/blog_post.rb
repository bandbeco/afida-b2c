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
# - Optional category for content organization
# - Structured content fields for templated blog posts (intro, CTAs, FAQ, etc.)
#
# Structured content JSONB fields are arrays. Expected shapes:
#
#   faq_items:            [{ "question" => "...", "answer" => "..." }]
#   decision_factors:     [{ "heading" => "...", "body" => "..." }]
#   buyer_setups:         [{ "title" => "...", "best_for" => "...", "body" => "...", "cta_label" => "...", "cta_url" => "..." }]
#   recommended_options:  [{ "heading" => "...", "body" => "...", "url" => "..." }]
#   top_cta_buttons:      [{ "label" => "...", "url" => "..." }]
#   final_cta_buttons:    [{ "label" => "...", "url" => "..." }]
#   internal_link_targets: [{ "label" => "...", "url" => "..." }]
#   target_category_slugs, target_collection_slugs, target_product_slugs: ["slug-1", "slug-2"]
#   secondary_keywords:   ["keyword one", "keyword two"]
#
class BlogPost < ApplicationRecord
  # ==========================================================================
  # Constants
  # ==========================================================================

  JSONB_ARRAY_FIELDS = %i[
    decision_factors buyer_setups recommended_options faq_items
    top_cta_buttons final_cta_buttons internal_link_targets
    target_category_slugs target_collection_slugs target_product_slugs
    secondary_keywords
  ].freeze

  STRUCTURED_TEXT_FIELDS = %i[
    intro conclusion
    top_cta_heading top_cta_body
    branding_heading branding_body
    final_cta_heading final_cta_body
    primary_keyword
  ].freeze

  # Required keys for JSONB object-array fields. Fields not listed here
  # contain simple strings and only get the array-of-strings check.
  JSONB_REQUIRED_KEYS = {
    faq_items: %w[question answer],
    decision_factors: %w[heading body],
    buyer_setups: %w[title best_for body cta_label cta_url],
    recommended_options: %w[heading body url],
    top_cta_buttons: %w[label url],
    final_cta_buttons: %w[label url],
    internal_link_targets: %w[label url]
  }.freeze

  # ==========================================================================
  # Associations
  # ==========================================================================

  belongs_to :blog_category, optional: true

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

  validate :jsonb_fields_are_arrays
  validate :jsonb_object_shapes

  # ==========================================================================
  # Callbacks
  # ==========================================================================

  before_validation :generate_slug
  before_validation :coerce_jsonb_nils
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

  # True when any structured template field has content.
  def structured?
    STRUCTURED_TEXT_FIELDS.any? { |field| self[field].present? } ||
      JSONB_ARRAY_FIELDS.any? { |field| self[field].present? }
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

  # Ensure JSONB fields are never nil at the model level
  def coerce_jsonb_nils
    JSONB_ARRAY_FIELDS.each do |field|
      self[field] = [] if self[field].nil?
    end
  end

  # Validate that JSONB fields contain arrays, not objects or scalars
  def jsonb_fields_are_arrays
    JSONB_ARRAY_FIELDS.each do |field|
      value = self[field]
      next if value.is_a?(Array)

      errors.add(field, "must be an array")
    end
  end

  # Validate that object-array JSONB fields have the expected keys.
  # Skips fields that already failed the array check.
  def jsonb_object_shapes
    JSONB_REQUIRED_KEYS.each do |field, required_keys|
      items = self[field]
      next unless items.is_a?(Array)

      items.each_with_index do |item, index|
        unless item.is_a?(Hash)
          errors.add(field, "item #{index + 1} must be an object")
          next
        end

        missing = required_keys - item.keys
        if missing.any?
          errors.add(field, "item #{index + 1} is missing required keys: #{missing.join(', ')}")
        end
      end
    end
  end
end
