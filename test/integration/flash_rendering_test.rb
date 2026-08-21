require "test_helper"

# The storefront flash bar. It is the only thing a customer sees when a
# discount is dropped at checkout, so it is pinned: a full-bleed square red
# band with no icon and no dismissal reads as breakage even when the message is
# a friendly nudge to spend a little more.
class FlashRenderingTest < ActionDispatch::IntegrationTest
  test "renders a notice as a dismissible info flash with an icon" do
    get cart_path
    follow_redirect! if response.redirect?

    # A notice is set by the ordinary empty-cart redirect path.
    delete cart_url
    follow_redirect!

    assert_select "[data-test=flash-notice]" do
      assert_select "[data-controller~=auto-dismiss]", count: 1
      assert_select "[data-test=flash-icon]", count: 1
      assert_select "[data-test=flash-dismiss]", count: 1
    end
  end

  test "the flash is inset rather than a full-bleed band" do
    delete cart_url
    follow_redirect!

    # A rounded, max-width container: the old bar spanned the viewport edge to
    # edge with square corners, which is what made it read as an error state.
    assert_select "[data-test=flash-notice].rounded-lg", count: 1
    assert_select "[data-test=flash-region].max-w-3xl", count: 1
  end

  test "uses no bold or semibold weights" do
    delete cart_url
    follow_redirect!

    flash_html = css_select("[data-test=flash-region]").to_s
    assert_no_match(/font-bold|font-semibold/, flash_html)
  end

  # The nudge is the flash this styling exists for: it tells a customer how to
  # save money, so it must not look like the two failure states. Rendered
  # directly, since no production route sets a nudge except a Stripe refusal
  # mid-checkout, and driving that here would test the checkout, not the styling.
  test "renders a nudge with its own palette and a gift emoji" do
    html = render_flash(:nudge, "Add £54.00 to your order to use it.")

    assert_match(/🎁/, html, "the nudge carries a friendly mark")
    assert_match(/bg-primary/, html, "the nudge has its own palette")
    assert_match(/Add £54\.00/, html)
  end

  test "a nudge never renders as the same thing as an alert" do
    nudge = render_flash(:nudge, "Add £54.00 to use it.")
    alert = render_flash(:alert, "Something went wrong.")

    assert_not_equal nudge, alert
    assert_match(/🎁/, nudge)
    assert_no_match(/🎁/, alert)
    assert_match(/bg-error/, alert, "a real failure still reads as one")
    assert_no_match(/bg-error/, nudge)
  end

  test "every flash kind is dismissible and announced to assistive tech" do
    assert_match(/role="status"/, render_flash(:nudge, "x"))
    assert_match(/role="status"/, render_flash(:notice, "x"))
    assert_match(/role="alert"/, render_flash(:alert, "x"))

    %i[nudge notice alert].each do |kind|
      assert_match(/data-test="flash-dismiss"/, render_flash(kind, "x"), "#{kind} should be dismissible")
      assert_match(/auto-dismiss/, render_flash(kind, "x"), "#{kind} should time out")
    end
  end

  private

  def render_flash(kind, message)
    ApplicationController.render(
      partial: "shared/flash",
      locals: { message: message, kind: kind }
    )
  end
end
