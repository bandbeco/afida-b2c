require "test_helper"

class BrandedProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:branded_template_variant)
  end

  test "show renders the branded product page" do
    get branded_product_url(@product)

    assert_response :success
  end

  # The JSON-LD blocks embed user-controllable model data (category name, product
  # title) inside <script type="application/ld+json">. A name containing
  # "</script>" must not break out of the script element: it has to be emitted in
  # its escaped </script> form, never as a literal closing tag + payload.
  test "show escapes a </script> payload in the category name within JSON-LD" do
    @product.category.update!(name: %(Cups</script><script>alert('xss')</script>))

    get branded_product_url(@product)

    assert_response :success
    assert_not_includes response.body, "</script><script>alert('xss')</script>"
    assert_includes response.body, "Cups\\u003c/script\\u003e\\u003cscript\\u003ealert('xss')\\u003c/script\\u003e"
  end

  test "show escapes a </script> payload in the product title within JSON-LD" do
    @product.update!(name: %(Evil</script><script>alert('xss')</script>))

    get branded_product_url(@product)

    assert_response :success
    assert_not_includes response.body, "</script><script>alert('xss')</script>"
  end
end
