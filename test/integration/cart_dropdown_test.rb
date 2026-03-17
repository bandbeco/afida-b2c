require "test_helper"

class CartDropdownTest < ActionDispatch::IntegrationTest
  test "cart dropdown has click-outside controller" do
    get root_url

    assert_response :success
    assert_select "details.dropdown[data-controller='click-outside']"
  end

  test "cart dropdown details element is the click-outside target" do
    get root_url

    assert_response :success
    assert_select "details[data-click-outside-target='details']"
  end
end
