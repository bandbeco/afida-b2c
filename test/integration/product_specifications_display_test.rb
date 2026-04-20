require "test_helper"

class ProductSpecificationsDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:single_wall_8oz_white)
  end

  test "renders dimensions group when dimension fields are populated" do
    @product.update_columns(
      length_in_mm: 254,
      width_in_mm: 90,
      height_in_mm: 120,
      weight_in_g: 450
    )

    get product_path(@product)

    assert_select "section[data-test='product-specifications']" do
      assert_select "h2", text: /Specifications/i
      assert_select "[data-test='specifications-dimensions']" do
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

  test "renders materials group when material fields are populated" do
    @product.update_columns(
      material: "Kraft paper",
      colour: "White",
      size: "8oz"
    )

    get product_path(@product)

    assert_select "section[data-test='product-specifications']" do
      assert_select "[data-test='specifications-materials']" do
        assert_select "dt", text: "Material"
        assert_select "dd", text: /Kraft paper/
        assert_select "dt", text: "Colour"
        assert_select "dd", text: /White/
        assert_select "dt", text: "Size"
        assert_select "dd", text: /8oz/
      end
    end
  end

  test "renders certifications as badges inside the materials group" do
    @product.update_columns(
      material: "Kraft paper",
      certifications: "FSC, Compostable, BPI"
    )

    get product_path(@product)

    assert_select "[data-test='specifications-materials']" do
      assert_select "dt", text: "Certifications"
      assert_select "dd [data-test='certification-badge']", count: 3
      assert_select "dd [data-test='certification-badge']", text: "FSC"
      assert_select "dd [data-test='certification-badge']", text: "Compostable"
      assert_select "dd [data-test='certification-badge']", text: "BPI"
    end
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

  test "hides empty rows within a populated group" do
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

    assert_select "[data-test='specifications-dimensions']" do
      assert_select "dt", text: "Length"
      assert_select "dt", text: "Weight"
      assert_select "dt", text: "Width", count: 0
      assert_select "dt", text: "Height", count: 0
    end
  end

  test "hides materials group when only dimensions are present" do
    @product.update_columns(
      length_in_mm: 254,
      material: nil, colour: nil, size: nil, certifications: nil
    )

    get product_path(@product)

    assert_select "[data-test='specifications-dimensions']"
    assert_select "[data-test='specifications-materials']", count: 0
  end

  test "hides dimensions group when only materials are present" do
    @product.update_columns(
      length_in_mm: nil, width_in_mm: nil, height_in_mm: nil,
      depth_in_mm: nil, diameter_in_mm: nil, weight_in_g: nil, volume_in_ml: nil,
      material: "PLA"
    )

    get product_path(@product)

    assert_select "[data-test='specifications-materials']"
    assert_select "[data-test='specifications-dimensions']", count: 0
  end
end
