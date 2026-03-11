require "test_helper"

class DesktopMegaMenuTest < ActionDispatch::IntegrationTest
  test "category nav renders mega-menu buttons for top-level categories on desktop" do
    get root_url

    assert_response :success

    # Should have the category nav bar (desktop)
    assert_select ".category-mega-menu" do
      # Should render top-level categories as buttons (not links)
      assert_select "button[data-category-mega-menu-target='trigger']", minimum: 1
    end
  end

  test "category nav does not render old hardcoded flat links" do
    get root_url

    assert_response :success

    # Old hardcoded categories should NOT appear as flat links
    assert_select "a[href='/categories/cups-and-lids']", count: 0
    assert_select "a[href='/categories/takeaway-extras']", count: 0
    assert_select "a[href='/categories/takeaway-containers']", count: 0
  end

  test "mega-menu panels contain subcategory links" do
    get root_url

    assert_response :success

    # Each mega-menu panel should have subcategory links
    assert_select "[data-category-mega-menu-target='panel']" do
      assert_select "a", minimum: 1
    end
  end

  test "mega-menu panels have view all links" do
    get root_url

    assert_response :success

    # Each panel should have a "View all" link to the parent category
    assert_select "[data-category-mega-menu-target='panel'] a", text: /View all/i, minimum: 1
  end

  test "subcategory links use nested URLs" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get root_url

    assert_response :success

    # Subcategory links should use the nested URL pattern
    expected_path = category_subcategory_path(parent.slug, subcategory.slug)
    assert_select "a[href='#{expected_path}']"
  end

  test "mega-menu buttons have aria-expanded attribute" do
    get root_url

    assert_response :success

    assert_select "button[data-category-mega-menu-target='trigger'][aria-expanded='false']", minimum: 1
  end

  test "mega-menu buttons have aria-haspopup attribute" do
    get root_url

    assert_response :success

    assert_select "button[data-category-mega-menu-target='trigger'][aria-haspopup='true']", minimum: 1
  end


  test "category nav shows category icons" do
    get root_url

    assert_response :success

    # Top-level buttons should include chevron SVGs
    assert_select ".category-mega-menu button svg", minimum: 1
  end

  test "desktop category nav is hidden on mobile" do
    get root_url

    assert_response :success

    # Desktop nav should have hidden class for mobile, visible for lg+
    assert_select ".category-mega-menu.hidden.lg\\:block"
  end

  test "mobile category pill bar is removed" do
    get root_url

    assert_response :success

    # The old mobile horizontal scroll category bar should not exist
    assert_select ".scrollbar-hide", count: 0
  end
end
