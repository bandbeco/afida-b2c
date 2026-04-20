class ProductSpecification
  DIMENSION_FIELDS = [
    { label: "Length",   attribute: :length_in_mm,   unit: "mm" },
    { label: "Width",    attribute: :width_in_mm,    unit: "mm" },
    { label: "Height",   attribute: :height_in_mm,   unit: "mm" },
    { label: "Depth",    attribute: :depth_in_mm,    unit: "mm" },
    { label: "Diameter", attribute: :diameter_in_mm, unit: "mm" },
    { label: "Weight",   attribute: :weight_in_g,    unit: "g"  },
    { label: "Volume",   attribute: :volume_in_ml,   unit: "ml" }
  ].freeze

  MATERIAL_FIELDS = [
    { label: "Material", attribute: :material },
    { label: "Colour",   attribute: :colour },
    { label: "Size",     attribute: :size }
  ].freeze

  def initialize(product)
    @product = product
  end

  def dimensions
    DIMENSION_FIELDS.each_with_object([]) do |field, acc|
      value = @product.public_send(field[:attribute])
      next if value.blank? || value.to_i.zero?
      acc << { label: field[:label], value: value, unit: field[:unit] }
    end
  end

  def materials
    MATERIAL_FIELDS.each_with_object([]) do |field, acc|
      value = @product.public_send(field[:attribute])
      next if value.blank?
      acc << { label: field[:label], value: value }
    end
  end

  def certifications
    raw = @product.certifications
    return [] if raw.blank?

    raw.split("/").map(&:strip).reject(&:blank?)
  end

  def dimensions?
    dimensions.any?
  end

  def materials?
    materials.any?
  end

  def certifications?
    certifications.any?
  end

  def any?
    dimensions? || materials? || certifications?
  end
end
