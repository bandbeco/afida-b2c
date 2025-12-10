import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for GA4 e-commerce tracking
 *
 * Handles events that need to fire on user interaction rather than page load,
 * such as begin_checkout when clicking the checkout button.
 *
 * Usage:
 *   <button data-controller="analytics"
 *           data-action="click->analytics#beginCheckout"
 *           data-analytics-cart-value="100.00"
 *           data-analytics-cart-items-value='[...]'>
 *     Checkout
 *   </button>
 */
export default class extends Controller {
  static values = {
    cartValue: Number,
    cartItems: Array
  }

  /**
   * Fires GA4 begin_checkout event before checkout redirect
   * Called when user clicks checkout button
   */
  beginCheckout(event) {
    if (typeof dataLayer === 'undefined') return

    dataLayer.push({ ecommerce: null })
    dataLayer.push({
      event: "begin_checkout",
      ecommerce: {
        currency: "GBP",
        value: this.cartValueValue,
        items: this.cartItemsValue
      }
    })
  }
}
