class BrandingImage < ApplicationRecord
  belongs_to :site_setting
  has_one_attached :image

  acts_as_list scope: :site_setting

  validates :alt_text, presence: true
  validate :acceptable_image, if: -> { image.attached? && image.blob&.new_record? }

  private

  def acceptable_image
    unless image.blob.content_type.in?(SiteSetting::ALLOWED_IMAGE_TYPES)
      errors.add(:image, "must be a PNG, JPEG, WebP, or GIF")
    end

    if image.blob.byte_size > SiteSetting::MAX_IMAGE_SIZE
      errors.add(:image, "must be less than 5MB")
    end
  end
end
