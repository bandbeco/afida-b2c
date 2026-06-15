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
end
