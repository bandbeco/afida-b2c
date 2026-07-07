class CategorySlugRedirect < ApplicationRecord
  belongs_to :category

  validates :old_slug, presence: true, uniqueness: true
end
