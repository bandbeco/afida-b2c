# frozen_string_literal: true

# Represents a blog post category for organizing content.
#
# Categories like "Customer Stories", "News", "Guides" help readers
# find content and enable related post recommendations.
#
class BlogCategory < ApplicationRecord
  has_many :blog_posts, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  before_validation :generate_slug

  # URL generation uses slug instead of ID
  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present? || name.blank?

    self.slug = name.parameterize
  end
end
