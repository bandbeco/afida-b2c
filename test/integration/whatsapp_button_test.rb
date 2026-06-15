require "test_helper"

class WhatsappButtonTest < ActionDispatch::IntegrationTest
  test "homepage renders the floating WhatsApp button with correct link and attributes" do
    get root_path

    assert_response :success

    # The wa.me link to the business number with the prefilled message (URL-encoded).
    assert_select "a[href=?]",
      "https://wa.me/447595119603?text=Hi%20Afida%2C%20I%20have%20a%20question%20about" do |links|
      assert_equal 1, links.size, "expected exactly one WhatsApp button on the page"
    end

    # Opens in a new context without leaking the opener.
    assert_select "a[href^='https://wa.me/447595119603'][target='_blank']"
    assert_select "a[href^='https://wa.me/447595119603'][rel~='noopener']"

    # Accessible name for screen readers.
    assert_select "a[href^='https://wa.me/447595119603'][aria-label='Chat with us on WhatsApp']"

    # Inline SVG glyph is present inside the link.
    assert_select "a[href^='https://wa.me/447595119603'] svg"
  end

  test "product page lifts the WhatsApp button above the mobile add-to-cart bar" do
    get product_path(products(:one).slug)

    assert_response :success
    # The lift class is applied so the button clears the mobile sticky add-to-cart bar.
    assert_select "a[href^='https://wa.me/447595119603'].max-md\\:bottom-24"
  end

  test "non-product pages do not apply the lift class" do
    get root_path

    assert_response :success
    assert_select "a[href^='https://wa.me/447595119603']"
    assert_select "a[href^='https://wa.me/447595119603'].max-md\\:bottom-24", false,
      "homepage should not lift the WhatsApp button (no add-to-cart bar there)"
  end

  test "admin pages do not render the WhatsApp button" do
    sign_in_as(users(:acme_admin))
    get admin_path

    assert_response :success
    assert_select "a[href^='https://wa.me/447595119603']", false,
      "the WhatsApp button must not appear in the admin area"
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect!
  end
end
