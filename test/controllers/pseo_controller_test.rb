require "test_helper"

class PseoControllerTest < ActionDispatch::IntegrationTest
  test "business_type page returns 200 for valid slug" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_response :success
  end

  test "business_type page returns 404 for unknown slug" do
    assert_raises(ActionController::RoutingError) do
      get pseo_business_type_path(business_type: "nonexistent-business")
    end
  end

  test "business_type page sets correct SEO title" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "title", "Packaging Supplies for Coffee Shops | Afida"
  end

  test "business_type page sets meta description" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "meta[name='description'][content=?]",
      /Wholesale packaging for coffee shops/
  end

  test "business_type page renders H1 headline" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "h1", /Packaging Built for Coffee Shops/
  end

  test "business_type page renders intro paragraph" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "p", /Running a coffee shop means/
  end

  test "business_type page renders packaging needs cards" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "[data-testid='packaging-needs'] [data-testid='packaging-card']", { count: 5 }
  end

  test "business_type page renders FAQ accordion" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select ".collapse", { minimum: 5 }
  end

  test "business_type page renders sustainability section" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "[data-testid='sustainability-section']"
  end

  test "business_type page has FAQPage structured data" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes response.body, "FAQPage"
  end

  test "business_type page has BreadcrumbList structured data" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_includes response.body, "BreadcrumbList"
  end

  test "business_type page has canonical URL" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "link[rel='canonical']"
  end

  test "business_type page renders CTA section" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "[data-testid='cta-section']"
    assert_select "a", /Shop.*Packaging/
  end

  test "business_type page prevents path traversal" do
    assert_raises(ActionController::RoutingError) do
      get pseo_business_type_path(business_type: "../../../etc/passwd")
    end
  end

  test "business_type page renders social proof section" do
    get pseo_business_type_path(business_type: "coffee-shops")

    assert_select "[data-testid='social-proof']"
  end
end
