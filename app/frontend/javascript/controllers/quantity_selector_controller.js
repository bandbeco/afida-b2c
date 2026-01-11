import { Controller } from "@hotwired/stimulus"

/**
 * Quantity Selector Controller
 *
 * Handles quantity selection for product pages with +/- buttons,
 * updates total price display, and syncs quantity to form hidden input.
 *
 * Targets:
 * - input: The quantity number input
 * - totalDisplay: Element showing calculated total price
 * - quantityInput: Hidden form input to sync quantity value
 * - unitsDisplay: Optional element showing total units (quantity × pac_size)
 *
 * Values:
 * - price: Base price per unit/pack
 * - pacSize: Number of units per pack (for display purposes)
 */
export default class extends Controller {
  static targets = ["input", "totalDisplay", "quantityInput", "unitsDisplay"]
  static values = {
    price: Number,
    pacSize: { type: Number, default: 1 }
  }

  connect() {
    this.updateTotal()
  }

  increment() {
    const input = this.inputTarget
    const currentValue = parseInt(input.value, 10) || 1
    const max = parseInt(input.max, 10) || 999

    if (currentValue < max) {
      input.value = currentValue + 1
      this.updateTotal()
    }
  }

  decrement() {
    const input = this.inputTarget
    const currentValue = parseInt(input.value, 10) || 1
    const min = parseInt(input.min, 10) || 1

    if (currentValue > min) {
      input.value = currentValue - 1
      this.updateTotal()
    }
  }

  updateTotal() {
    const quantity = parseInt(this.inputTarget.value, 10) || 1

    // Update total display
    const total = quantity * this.priceValue
    if (this.hasTotalDisplayTarget) {
      this.totalDisplayTarget.textContent = this.formatCurrency(total)
    }

    // Sync to hidden form input
    if (this.hasQuantityInputTarget) {
      this.quantityInputTarget.value = quantity
    }

    // Update units display if present
    if (this.hasUnitsDisplayTarget && this.pacSizeValue > 1) {
      const totalUnits = quantity * this.pacSizeValue
      this.unitsDisplayTarget.textContent = `(${this.formatNumber(totalUnits)} units)`
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency: "GBP"
    }).format(amount)
  }

  formatNumber(num) {
    return new Intl.NumberFormat("en-GB").format(num)
  }
}
