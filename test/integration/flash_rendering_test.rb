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

    # auto-dismiss rides the opaque wrapper that the tinted panel sits on, so
    # the whole toast slides out as one piece.
    assert_select "[data-test=flash-region] [data-controller~=auto-dismiss]", count: 1
    assert_select "[data-test=flash-notice]" do
      assert_select "[data-test=flash-icon]", count: 1
      assert_select "[data-test=flash-dismiss]", count: 1
    end
  end

  test "the flash is inset rather than a full-bleed band" do
    delete cart_url
    follow_redirect!

    # A rounded, corner-anchored panel: the old bar spanned the viewport edge
    # to edge with square corners, which is what made it read as an error
    # state. DaisyUI's .toast already caps itself at calc(100vw - 2rem), so the
    # panel only needs its own comfortable reading width.
    assert_select "[data-test=flash-notice].rounded-lg", count: 1
    assert_select "[data-test=flash-region] .max-w-sm", count: 1
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

  # The flash used to render as a block element at the top of <body>, above the
  # banner and navbar, so its arrival pushed the entire page down and its
  # auto-dismissal snapped it back up: two layout shifts per message, the second
  # landing while the customer is still reading or mid-click.
  test "the flash overlays the page instead of displacing it" do
    delete cart_url
    follow_redirect!

    assert_select "[data-test=flash-region].toast", count: 1,
      message: "the flash region should be a DaisyUI toast, which is position:fixed"
  end

  test "the flash toast is pinned to the top right" do
    delete cart_url
    follow_redirect!

    assert_select "[data-test=flash-region].toast-top", count: 1
    assert_select "[data-test=flash-region].toast-end", count: 1
    assert_select "[data-test=flash-region].toast-center", count: 0
  end

  # The toast overlays whatever is beneath it rather than being nudged clear of
  # the header, so it needs no bespoke offset stylesheet.
  test "the toast keeps DaisyUI's own corner offset" do
    assert_not Rails.root.join("app/frontend/stylesheets/components/flash_toast.css").exist?,
      "positioning should come from DaisyUI, not a bespoke offset rule"
  end

  # It arrives from the right edge it is anchored to.
  test "the flash slides in from the right" do
    delete cart_url
    follow_redirect!

    assert_select "[data-test=flash-region] [data-auto-dismiss-animation-value=slide-right]", count: 1
  end

  test "the flash region no longer reserves layout width in the document flow" do
    delete cart_url
    follow_redirect!

    # mx-auto was the in-flow centring of the old block element. The toast
    # container does its own positioning, and the width now belongs to the
    # panel inside it.
    assert_select "[data-test=flash-region].mx-auto", count: 0
  end

  # A fixed toast has to declare its own stacking order; the old in-flow bar
  # never needed one because it occupied real space. Without this the flash is
  # painted underneath the header, which sits at z-50/z-60.
  test "the flash toast stacks above the header" do
    delete cart_url
    follow_redirect!

    assert_select "[data-test=flash-region].z-\\[70\\]", count: 1
  end

  test "every kind renders inside the toast container" do
    %i[nudge notice alert].each do |kind|
      html = render_flash(kind, "x")
      assert_match(/toast toast-top toast-end/, html, "#{kind} should be toasted")
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
