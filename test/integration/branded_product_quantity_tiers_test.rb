require "test_helper"

class BrandedProductQuantityTiersTest < ActionDispatch::IntegrationTest
  test "quantity tier cards do not use inline styles" do
    product = products(:branded_template_variant)

    get branded_product_path(product.slug, size: "8oz", quantity: 1000)

    assert_response :success
    assert_select "[data-branded-configurator-target='quantityOption']" do |cards|
      cards.each do |card|
        assert_nil card["style"], "Quantity tier card should not have inline styles"
      end
    end
  end

  test "quantity tier price columns do not use inline width styles" do
    product = products(:branded_template_variant)

    get branded_product_path(product.slug, size: "8oz", quantity: 1000)

    assert_response :success
    assert_select "[data-branded-configurator-target='pricePerUnit']" do |elements|
      elements.each do |el|
        assert_nil el["style"], "Price per unit column should not have inline styles"
      end
    end
    assert_select "[data-branded-configurator-target='savingsBadge']" do |elements|
      elements.each do |el|
        assert_nil el["style"], "Savings badge column should not have inline styles"
      end
    end
    assert_select "[data-branded-configurator-target='totalPrice']" do |elements|
      elements.each do |el|
        assert_nil el["style"], "Total price column should not have inline styles"
      end
    end
  end
end
