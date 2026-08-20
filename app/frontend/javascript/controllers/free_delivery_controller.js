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

    const remaining = this.thresholdValue - this.cartSubtotalValue - this.pageTotal

    this.messageTarget.textContent = remaining > 0
      ? `Add ${this.formatCurrency(remaining)} more for free mainland UK delivery`
      : "This order qualifies for free mainland UK delivery"
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency: "GBP"
    }).format(amount)
  }
}
