# frozen_string_literal: true

class LegacyRedirect < ApplicationRecord
  # Validations
  validates :legacy_path, presence: true, uniqueness: { case_sensitive: false }
  validates :target_slug, presence: true
  validates :legacy_path, format: { with: %r{\A/product/.*\z}, message: "must start with /product/" }
  validate :target_slug_exists

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :most_used, -> { order(hit_count: :desc) }
  scope :recently_updated, -> { order(updated_at: :desc) }

  # Class Methods
  def self.find_by_path(path)
    where("LOWER(legacy_path) = ?", path.downcase).first
  end

  # Instance Methods
  def record_hit!
    increment!(:hit_count)
  end

  def target_url
    url = "/products/#{target_slug}"
    if variant_params.present?
      query_string = variant_params.to_query
      url += "?#{query_string}"
    end
    url
  end

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end

  private

  def target_slug_exists
    return if target_slug.blank?

    unless Product.exists?(slug: target_slug)
      errors.add(:target_slug, "product not found")
    end
  end
end
