import { Controller } from "@hotwired/stimulus"

/**
 * Free Delivery Controller
 *
 * Counts a buyer down to the free-delivery threshold instead of restating the
 * rule. The server supplies the threshold and what the cart already holds; this
 * adds what the page is about to add and reports the gap, flipping to a
 * qualified message once it closes.
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
 * - openingTotal: What the page starts out offering to add, in pounds
 */
export default class extends Controller {
  static targets = ["message"]
  static values = {
    threshold: Number,
    cartSubtotal: { type: Number, default: 0 },
    openingTotal: { type: Number, default: 0 }
  }

  // Renders immediately rather than waiting for the first interaction: a buyer
  // arriving with a full cart would otherwise be told to reach a threshold they
  // already passed. The buy box's own opening total covers the gap until the
  // first change event arrives.
  connect() {
    this.pageTotal = this.openingTotalValue
    this.render()
  }

  totalChanged(event) {
    this.pageTotal = event.detail.total || 0
    this.render()
  }

  render() {
    if (!this.hasMessageTarget || !this.thresholdValue) return

    // The gap counts the cart plus what this page would add, because ticking a
    // lid genuinely moves the buyer closer. But the sentence has to match what
    // they have actually committed to: with an empty cart, "add £61 more" reads
    // as £61 on top of a £39 they have not bought yet. Only once something is
    // in the cart is "more" true.
    const selection = this.cartSubtotalValue + this.pageTotal
    const remaining = this.thresholdValue - selection

    if (remaining <= 0) {
      this.messageTarget.textContent = "This order qualifies for free mainland UK delivery"
    } else if (this.cartSubtotalValue > 0) {
      this.messageTarget.textContent =
        `Add ${this.formatCurrency(remaining)} more for free mainland UK delivery`
    } else {
      // The threshold is a round figure, so it reads without decimals here,
      // matching the server-rendered copy this replaces on connect.
      this.messageTarget.textContent =
        `Free mainland UK delivery on orders over ${this.formatCurrency(this.thresholdValue, 0)}`
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
