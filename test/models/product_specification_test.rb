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

  test "#certifications splits on comma and strips whitespace" do
    spec = ProductSpecification.new(product_with(
      certifications: "FSC, Compostable, BPI"
    ))
    assert_equal [ "FSC", "Compostable", "BPI" ], spec.certifications
  end

  test "#certifications ignores empty tokens from adjacent or trailing commas" do
    spec = ProductSpecification.new(product_with(
      certifications: "FSC ,,Compostable,"
    ))
    assert_equal [ "FSC", "Compostable" ], spec.certifications
  end

  # Recyclability is a property of the material, not a certification anyone
  # awarded. Listed under Certifications beside FSC and EN 13432 it reads as a
  # padded claim, which is exactly the wrong impression for buyers who chose
  # this shop on its environmental credentials.
  test "#certifications leaves out material properties" do
    spec = ProductSpecification.new(product_with(
      certifications: "FSC, Recyclable, EN 13432"
    ))
    assert_equal [ "FSC", "EN 13432" ], spec.certifications
  end

  test "material properties join the materials rows" do
    spec = ProductSpecification.new(product_with(
      material: "Kraft paper", certifications: "FSC, Recyclable"
    ))

    assert_includes spec.materials, { label: "Recyclable", value: "Yes" }
  end

  test "an unrecognised token stays a certification" do
    spec = ProductSpecification.new(product_with(certifications: "Home Compostable"))

    assert_equal [ "Home Compostable" ], spec.certifications
  end

  test "a product whose only certification is a material property still shows materials" do
    spec = ProductSpecification.new(product_with(certifications: "Recyclable"))

    refute spec.certifications?
    assert spec.materials?
    assert spec.any?
  end

  # Size already reads "9oz / 255ml", so a Volume row saying "255 ml" beside it
  # is the same fact twice, and it was the only row holding the Dimensions
  # column open on 65 products.
  test "#dimensions drops a volume the size already states" do
    spec = ProductSpecification.new(product_with(volume_in_ml: 255, size: "9oz / 255ml"))

    assert_empty spec.dimensions.select { |row| row[:label] == "Volume" }
  end

  test "#dimensions keeps a volume the size does not mention" do
    spec = ProductSpecification.new(product_with(volume_in_ml: 255, size: "Large"))

    assert_includes spec.dimensions.map { |row| row[:label] }, "Volume"
  end

  test "#dimensions keeps volume when there is no size at all" do
    spec = ProductSpecification.new(product_with(volume_in_ml: 255))

    assert_includes spec.dimensions.map { |row| row[:label] }, "Volume"
  end

  # A buyer comparing two products reads one list. Splitting six facts across
  # two headed columns, one of which often holds a single row, is filing rather
  # than presenting.
  test "#rows presents every spec as one ordered list" do
    spec = ProductSpecification.new(product_with(
      material: "rPET", colour: "Clear", size: "9oz / 255ml",
      length_in_mm: 95, certifications: "Recyclable"
    ))

    labels = spec.rows.map { |row| row[:label] }

    assert_equal labels.uniq, labels
    assert_includes labels, "Material"
    assert_includes labels, "Length"
    assert_includes labels, "Recyclable"
  end

  test "#rows leads with what a buyer identifies the product by" do
    spec = ProductSpecification.new(product_with(
      material: "rPET", size: "9oz / 255ml", length_in_mm: 95
    ))

    assert_equal "Size", spec.rows.first[:label]
  end

  test "#rows is empty when nothing is known" do
    assert_empty ProductSpecification.new(product_with).rows
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
