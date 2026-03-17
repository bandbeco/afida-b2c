require "test_helper"

class MobileDrillDownNavTest < ActionDispatch::IntegrationTest
  include CategoriesHelper
  test "mobile menu has slide-in panel container" do
    get root_url

    assert_response :success
    assert_select "[data-controller='mobile-menu']"
  end

  test "mobile menu has open button visible on mobile only" do
    get root_url

    assert_response :success
    # Hamburger button should exist and be hidden on lg+
    assert_select "button[data-action='mobile-menu#open']"
  end

  test "mobile menu has close button" do
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      assert_select "button[data-action='mobile-menu#close']"
    end
  end

  test "mobile menu contains Shop All link" do
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      assert_select "a[href='#{shop_path}']", text: "Shop All"
    end
  end

  test "mobile menu contains top-level categories with drill-down arrows" do
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      Category.browsable.top_level.each do |cat|
        assert_select "button[data-action='mobile-menu#drillDown']", text: /#{Regexp.escape(cat.name)}/
      end
    end
  end

  test "mobile menu contains subcategory panels for each top-level category" do
    get root_url

    assert_response :success

    Category.browsable.top_level.includes(:children).each do |cat|
      assert_select "[data-mobile-menu-target='subcategoryPanel'][data-category='#{cat.slug}']" do
        # Back button
        assert_select "button[data-action='mobile-menu#goBack']"
        # Category heading
        assert_select "span", text: cat.name
        # View all link
        assert_select "a[href='#{category_browse_path(cat)}']", text: /View all/i
        # Subcategory links
        cat.children.each do |sub|
          assert_select "a[href='#{category_browse_path(sub)}']", text: sub.name
        end
      end
    end
  end

  test "mobile menu contains Branding, Free Samples, and Price List links" do
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      assert_select "a[href='#{branding_path}']", text: "Branding"
      assert_select "a[href='#{samples_path}']", text: "Free Samples"
      assert_select "a[href='#{price_list_path}']", text: "Price List"
    end
  end

  test "mobile menu shows sign in and sign up when logged out" do
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      assert_select "a[href='#{new_session_path}']", text: "Sign In"
      assert_select "a[href='#{new_registration_path}']", text: "Sign Up"
    end
  end

  test "mobile menu shows account links when logged in" do
    sign_in_as(users(:one))
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel']" do
      assert_select "a[href='#{orders_path}']", text: "Orders"
      assert_select "a[href='#{reorder_schedules_path}']", text: "Scheduled Reorders"
      assert_select "a[href='#{account_addresses_path}']", text: "Addresses"
      assert_select "a[href='#{account_path}']", text: "Account Settings"
      assert_select "a[data-turbo-method='delete']", text: "Logout"
    end
  end

  test "mobile menu does not show sign in when logged in" do
    sign_in_as(users(:one))
    get root_url

    assert_response :success
    assert_select "[data-mobile-menu-target='panel'] a[href='#{new_session_path}']", text: "Sign In", count: 0
    assert_select "[data-mobile-menu-target='panel'] a[href='#{new_registration_path}']", text: "Sign Up", count: 0
  end

  test "mobile menu panel is hidden by default" do
    get root_url

    assert_response :success
    # Panel should be off-screen by default (translated left)
    assert_select "[data-mobile-menu-target='panel'].-translate-x-full"
  end

  test "mobile menu is only visible below lg breakpoint" do
    get root_url

    assert_response :success
    # The mobile menu controller wrapper should be lg:hidden
    assert_select "[data-controller='mobile-menu'].lg\\:hidden"
  end

  test "old mobile dropdown menu is removed" do
    get root_url

    assert_response :success
    # The old DaisyUI dropdown menu in the navbar should not exist
    assert_select ".navbar .dropdown.lg\\:hidden ul.dropdown-content", count: 0
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
    follow_redirect!
  end
end
