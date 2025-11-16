class ProductOption < ApplicationRecord
  has_many :values, -> { order(:position) },
           class_name: "ProductOptionValue",
           dependent: :destroy
  has_many :assignments, class_name: "ProductOptionAssignment", dependent: :destroy
  has_many :products, through: :assignments

  enum :display_type, { dropdown: "dropdown", radio: "radio", swatch: "swatch" }, validate: true

  # Normalize name to lowercase before validation
  before_validation :normalize_name

  validates :name, presence: true
  validates :name, format: { with: /\A[a-z_]+\z/, message: "must be lowercase letters and underscores only" }
  validates :display_type, presence: true

  default_scope { order(:position) }

  private

  def normalize_name
    self.name = name.to_s.downcase.strip if name.present?
  end
end
