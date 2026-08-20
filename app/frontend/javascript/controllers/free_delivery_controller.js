import { Controller } from "@hotwired/stimulus"

/**
 * Free Delivery Controller
 *
 * Counts a buyer down to the free-delivery threshold instead of restating the
 * rule. The gap is the threshold minus what the cart already holds, and nothing
 * else: what this page is offering to add is not money the buyer has spent, so
 * it must not move the figure.
 *
 * The figures mirror the canonical rule (products subtotal excluding VAT, gross
 * of discounts) and the promise stays mainland-qualified, because the product
 * page does not know where the order is going. Checkout remains the only
 * authority on what is actually charged.
 *
 * Targets:
 * - message: The sentence shown to the buyer
 *
 * Values:
 * - threshold: Free-delivery threshold in pounds
 * - cartSubtotal: Products subtotal already in the cart, in pounds
 */
export default class extends Controller {
  static targets = ["message"]
  static values = {
    threshold: Number,
    cartSubtotal: { type: Number, default: 0 }
  }

  connect() {
    this.render()
  }

  render() {
    if (!this.hasMessageTarget || !this.thresholdValue) return

    const remaining = this.thresholdValue - this.cartSubtotalValue

    if (remaining <= 0) {
      this.messageTarget.textContent = "This order qualifies for free mainland UK delivery"
    } else if (this.cartSubtotalValue > 0) {
      this.messageTarget.textContent =
        `Add ${this.formatCurrency(remaining)} more for free mainland UK delivery`
    } else {
      // An empty cart has nothing to count down from, so state the rule. The
      // threshold is a round figure and reads without decimals here, matching
      // the server-rendered copy this replaces on connect.
      this.messageTarget.textContent =
        `Free delivery on mainland UK orders over ${this.formatCurrency(this.thresholdValue, 0)}`
    }
  }

  formatCurrency(amount, decimals = 2) {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency: "GBP",
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    }).format(amount)
  }
}
