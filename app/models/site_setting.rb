class SiteSetting < ApplicationRecord
  has_one_attached :hero_image
  has_many :branding_images, -> { order(:position) }, dependent: :destroy

  validates :hero_background_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color (e.g. #ffffff)" }

  def self.instance
    first_or_create!(hero_background_color: "#ffffff")
  end

  def collage_images
    branding_images.limit(4)
  end
end
