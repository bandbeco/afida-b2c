class SiteSetting < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  has_one_attached :hero_image
  has_many :branding_images, -> { order(:position) }, dependent: :destroy

  validates :hero_background_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color (e.g. #ffffff)" }
  validate :acceptable_hero_image, if: -> { hero_image.attached? && hero_image.blob&.new_record? }

  def self.instance
    first_or_create!(hero_background_color: "#ffffff")
  rescue ActiveRecord::RecordNotUnique
    first
  end

  def collage_images
    branding_images.limit(4)
  end

  private

  def acceptable_hero_image
    unless hero_image.blob.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:hero_image, "must be a PNG, JPEG, WebP, or GIF")
    end

    if hero_image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:hero_image, "must be less than 5MB")
    end
  end
end
