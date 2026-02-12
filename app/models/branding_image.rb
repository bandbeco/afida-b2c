class BrandingImage < ApplicationRecord
  belongs_to :site_setting
  has_one_attached :image

  acts_as_list scope: :site_setting

  validates :alt_text, presence: true
end
