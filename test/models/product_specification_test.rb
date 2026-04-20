require "test_helper"

class ProductSpecificationTest < ActiveSupport::TestCase
  def product_with(**attrs)
    Product.new(attrs)
  end

  # ---- dimensions ----

  test "#dimensions is empty when all dimension columns are nil" do
    spec = ProductSpecification.new(product_with)
    assert_equal [], spec.dimensions
  end

  test "#dimensions is empty when all dimension columns are zero" do
    spec = ProductSpecification.new(product_with(
      length_in_mm: 0, width_in_mm: 0, height_in_mm: 0,
      depth_in_mm: 0, diameter_in_mm: 0, weight_in_g: 0, volume_in_ml: 0
    ))
    assert_equal [], spec.dimensions
  end

  test "#dimensions omits blank and zero fields and preserves canonical order" do
    spec = ProductSpecification.new(product_with(
      length_in_mm: 254,
      width_in_mm: nil,
      height_in_mm: 0,
      weight_in_g: 450
    ))

    assert_equal(
      [
        { label: "Length", value: 254, unit: "mm" },
        { label: "Weight", value: 450, unit: "g" }
      ],
      spec.dimensions
    )
  end

  test "#dimensions returns all fields in canonical order for fully populated product" do
    spec = ProductSpecification.new(product_with(
      length_in_mm: 100,
      width_in_mm: 80,
      height_in_mm: 120,
      depth_in_mm: 50,
      diameter_in_mm: 75,
      weight_in_g: 300,
      volume_in_ml: 250
    ))

    labels = spec.dimensions.map { |d| d[:label] }
    assert_equal %w[Length Width Height Depth Diameter Weight Volume], labels
  end

  # ---- materials ----

  test "#materials is empty when material, colour, and size are all blank" do
    spec = ProductSpecification.new(product_with)
    assert_equal [], spec.materials
  end

  test "#materials omits blank fields and preserves canonical order" do
    spec = ProductSpecification.new(product_with(
      material: "Kraft paper",
      colour: "",
      size: "8oz"
    ))

    assert_equal(
      [
        { label: "Material", value: "Kraft paper" },
        { label: "Size", value: "8oz" }
      ],
      spec.materials
    )
  end

  test "#materials returns material, colour, size in canonical order when all present" do
    spec = ProductSpecification.new(product_with(
      material: "PLA", colour: "White", size: "12oz"
    ))

    labels = spec.materials.map { |m| m[:label] }
    assert_equal %w[Material Colour Size], labels
  end

  # ---- certifications ----

  test "#certifications is empty for nil certifications" do
    spec = ProductSpecification.new(product_with(certifications: nil))
    assert_equal [], spec.certifications
  end

  test "#certifications is empty for blank certifications" do
    spec = ProductSpecification.new(product_with(certifications: "  "))
    assert_equal [], spec.certifications
  end

  test "#certifications splits on slash and strips whitespace" do
    spec = ProductSpecification.new(product_with(
      certifications: "FSC / Compostable / BPI"
    ))
    assert_equal [ "FSC", "Compostable", "BPI" ], spec.certifications
  end

  test "#certifications ignores empty tokens from adjacent or trailing slashes" do
    spec = ProductSpecification.new(product_with(
      certifications: "FSC //Compostable/"
    ))
    assert_equal [ "FSC", "Compostable" ], spec.certifications
  end

  # ---- group predicates and #any? ----

  test "#any? is false when dimensions, materials, and certifications are all empty" do
    spec = ProductSpecification.new(product_with)
    refute spec.any?
    refute spec.dimensions?
    refute spec.materials?
    refute spec.certifications?
  end

  test "#any? is true when only a dimension is present" do
    spec = ProductSpecification.new(product_with(length_in_mm: 100))
    assert spec.any?
    assert spec.dimensions?
    refute spec.materials?
    refute spec.certifications?
  end

  test "#any? is true when only a material is present" do
    spec = ProductSpecification.new(product_with(material: "PLA"))
    assert spec.any?
    refute spec.dimensions?
    assert spec.materials?
    refute spec.certifications?
  end

  test "#any? is true when only certifications are present" do
    spec = ProductSpecification.new(product_with(certifications: "FSC"))
    assert spec.any?
    refute spec.dimensions?
    refute spec.materials?
    assert spec.certifications?
  end
end
