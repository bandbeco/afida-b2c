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

  # Tokens the certifications column carries that nobody actually certifies.
  # They describe what the material does, so they belong beside Material rather
  # than beside FSC and EN 13432, where they read as a padded claim. Anything
  # unrecognised is left alone: a real certification we have not seen before
  # must not be quietly demoted.
  MATERIAL_PROPERTIES = [ "recyclable" ].freeze

  def initialize(product)
    @product = product
  end

  # The order a buyer scans in: what identifies the product, then what it is
  # made of, then the measurements, then the claims. One list rather than
  # headed groups, because the fields are sparse enough (no single one covers
  # the catalogue) that grouping regularly leaves a heading holding one row.
  ROW_ORDER = [ "Size", "Material", "Colour" ].freeze

  def dimensions
    DIMENSION_FIELDS.each_with_object([]) do |field, acc|
      value = @product.public_send(field[:attribute])
      next if value.blank? || value.to_i.zero?
      next if field[:label] == "Volume" && size_states_volume?
      acc << { label: field[:label], value: value, unit: field[:unit] }
    end
  end

  # Every measured spec as one ordered list, for a presentation that does not
  # have to know which group a field came from. Certifications stay out of it:
  # they are named awards ("FSC", "EN 13432"), not label/value facts, and they
  # render as badges.
  def rows
    ordered = materials.sort_by do |row|
      [ ROW_ORDER.index(row[:label]) || ROW_ORDER.size, row[:label] ]
    end

    ordered + dimensions
  end

  def materials
    rows = MATERIAL_FIELDS.each_with_object([]) do |field, acc|
      value = @product.public_send(field[:attribute])
      next if value.blank?
      acc << { label: field[:label], value: value }
    end

    rows + material_properties.map { |property| { label: property, value: "Yes" } }
  end

  def certifications
    declared_certifications.reject { |token| material_property?(token) }
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

  private

  def declared_certifications
    raw = @product.certifications
    return [] if raw.blank?

    raw.split(",").map(&:strip).reject(&:blank?)
  end

  def material_properties
    declared_certifications.select { |token| material_property?(token) }
  end

  def material_property?(token)
    MATERIAL_PROPERTIES.include?(token.downcase)
  end

  # Sizes are written as "9oz / 255ml", so a Volume row reading "255 ml" beside
  # one repeats a fact the buyer has already read, and on many products it was
  # the only row holding the dimensions group open.
  def size_states_volume?
    volume = @product.volume_in_ml
    return false if volume.blank? || volume.to_i.zero?

    size = @product.size.to_s.downcase.delete(" ")
    return false if size.blank?

    size.include?("#{volume.to_i}ml")
  end
end
