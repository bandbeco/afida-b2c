require "test_helper"

class ProductSpecificationsDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:single_wall_8oz_white)
  end

  test "renders measurements as tiles when dimension fields are populated" do
    @product.update_columns(
      length_in_mm: 254,
      width_in_mm: 90,
      height_in_mm: 120,
      weight_in_g: 450
    )

    get product_path(@product)

    assert_select "section[data-test='product-specifications']" do
      assert_select "h2", text: /Specifications/i
      assert_select "[data-test='specification-tile']" do
        assert_select "dt", text: "Length"
        assert_select "dd", text: /254\s*mm/
        assert_select "dt", text: "Width"
        assert_select "dd", text: /90\s*mm/
        assert_select "dt", text: "Height"
        assert_select "dd", text: /120\s*mm/
        assert_select "dt", text: "Weight"
        assert_select "dd", text: /450\s*g/
      end
    end
  end

  test "renders material facts as tiles" do
    @product.update_columns(
      material: "Kraft paper",
      colour: "White",
      size: "8oz"
    )

    get product_path(@product)

    assert_select "[data-test='specification-tile']" do
      assert_select "dt", text: "Material"
      assert_select "dd", text: /Kraft paper/
      assert_select "dt", text: "Colour"
      assert_select "dd", text: /White/
      assert_select "dt", text: "Size"
      assert_select "dd", text: /8oz/
    end
  end

  # Certifications are named awards, not label/value facts, so they read as
  # badges rather than as tiles with "Yes" in them.
  test "renders certifications as badges" do
    @product.update_columns(
      material: "Kraft paper",
      certifications: "FSC, Compostable, BPI"
    )

    get product_path(@product)

    assert_select "[data-test='specifications-certifications']" do
      assert_select "[data-test='certification-badge']", count: 3
      assert_select "[data-test='certification-badge']", text: "FSC"
      assert_select "[data-test='certification-badge']", text: "Compostable"
      assert_select "[data-test='certification-badge']", text: "BPI"
    end
  end

  test "recyclability reads as a material property, not a certification" do
    @product.update_columns(
      material: "Kraft paper",
      certifications: "FSC, Recyclable"
    )

    get product_path(@product)

    assert_select "[data-test='specification-tile'] dt", text: "Recyclable"
    assert_select "[data-test='certification-badge']", count: 1
    assert_select "[data-test='certification-badge']", text: "FSC"
  end

  # "9oz / 255ml" beside a Volume tile reading "255 ml" is the same fact twice,
  # and it was often the only measurement the product had.
  test "does not repeat a volume the size already states" do
    @product.update_columns(volume_in_ml: 255, size: "9oz / 255ml", material: "rPET")

    get product_path(@product)

    assert_select "[data-test='specification-tile'] dt", text: "Size"
    assert_select "[data-test='specification-tile'] dt", text: "Volume", count: 0
  end

  test "does not render the specifications section when all spec fields are blank" do
    @product.update_columns(
      length_in_mm: nil, width_in_mm: nil, height_in_mm: nil,
      depth_in_mm: nil, diameter_in_mm: nil, weight_in_g: nil, volume_in_ml: nil,
      material: nil, colour: nil, size: nil, certifications: nil
    )

    get product_path(@product)

    assert_select "section[data-test='product-specifications']", count: 0
  end

  test "hides empty measurements" do
    @product.update_columns(
      length_in_mm: 254,
      width_in_mm: nil,
      height_in_mm: 0,
      weight_in_g: 450,
      material: nil,
      colour: nil,
      size: nil,
      certifications: nil
    )

    get product_path(@product)

    assert_select "[data-test='specification-tile'] dt", text: "Length"
    assert_select "[data-test='specification-tile'] dt", text: "Weight"
    assert_select "[data-test='specification-tile'] dt", text: "Width", count: 0
    assert_select "[data-test='specification-tile'] dt", text: "Height", count: 0
  end

  # The old layout split these into two headed columns, so a product knowing
  # only one of them rendered a heading over a single row beside a gap.
  test "measurements and materials share one grid" do
    @product.update_columns(length_in_mm: 254, material: "PLA", size: nil, colour: nil)

    get product_path(@product)

    assert_select "[data-test='specifications-grid']" do
      assert_select "[data-test='specification-tile'] dt", text: "Length"
      assert_select "[data-test='specification-tile'] dt", text: "Material"
    end
  end

  test "renders with materials alone" do
    @product.update_columns(
      length_in_mm: nil, width_in_mm: nil, height_in_mm: nil,
      depth_in_mm: nil, diameter_in_mm: nil, weight_in_g: nil, volume_in_ml: nil,
      material: "PLA"
    )

    get product_path(@product)

    assert_select "[data-test='specification-tile'] dt", text: "Material"
  end
end
