import { Controller } from "@hotwired/stimulus"

/**
 * Pricing Tier Controller
 *
 * Handles tier selection (e.g. Case of 600 vs Pack of 50) and quantity
 * input for products with pricing_tiers. Updates price display, total,
 * and syncs selected tier data to hidden form fields.
 *
 * Targets:
 * - tierCard: Clickable tier cards
 * - input: Quantity number input
 * - totalDisplay: Total price display
 * - priceDisplay: Selected tier price display
 * - pacSizeDisplay: Selected tier pac_size display
 * - quantityInput: Hidden form field for quantity
 * - priceInput: Hidden form field for selected tier price
 * - pacSizeInput: Hidden form field for selected tier pac_size
 * - unitsDisplay: Total units display
 * - addToCartButton: Submit button (disabled until tier selected)
 *
 * Values:
 * - tiers: Array of { quantity, price } objects (from product.pricing_tiers)
 * - defaultPrice: The product's base price (pack_price from CSV)
 * - defaultPacSize: The product's base pac_size
 */
export default class extends Controller {
  static targets = [
    "tierCard", "input", "totalDisplay", "priceDisplay",
    "pacSizeDisplay", "quantityInput", "priceInput",
    "pacSizeInput", "unitsDisplay", "addToCartButton"
  ]

  static values = {
    tiers: Array,
    defaultPrice: Number,
    defaultPacSize: { type: Number, default: 1 }
  }

  connect() {
    // Auto-select the first tier (largest quantity = best value)
    // Tiers are sorted ascending by quantity, so last = case, first = pack
    // Select the first one by default (smallest/cheapest option)
    if (this.tierCardTargets.length > 0) {
      this.selectTierCard(this.tierCardTargets[0])
    }
  }

  selectTier(event) {
    this.selectTierCard(event.currentTarget)
  }

  handleCardKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.selectTierCard(event.currentTarget)
    }
  }

  selectTierCard(card) {
    // Deselect all
    this.tierCardTargets.forEach(el => {
      el.classList.remove("border-primary", "border-2")
      el.classList.add("border-gray-200", "border")
      el.setAttribute("aria-selected", "false")
    })

    // Select clicked card
    card.classList.remove("border-gray-200", "border")
    card.classList.add("border-primary", "border-2")
    card.setAttribute("aria-selected", "true")

    // Read tier data from card
    this.selectedPrice = parseFloat(card.dataset.tierPrice)
    this.selectedPacSize = parseInt(card.dataset.tierQuantity, 10)

    // Update hidden form fields
    if (this.hasPriceInputTarget) {
      this.priceInputTarget.value = this.selectedPrice
    }
    if (this.hasPacSizeInputTarget) {
      this.pacSizeInputTarget.value = this.selectedPacSize
    }

    // Update price display with selected tier info
    if (this.hasPriceDisplayTarget) {
      const label = this.selectedPacSize >= 100 ? "Case" : "Pack"
      this.priceDisplayTarget.textContent =
        `${this.formatCurrency(this.selectedPrice)} / ${label} of ${this.formatNumber(this.selectedPacSize)}`
    }

    // Enable add to cart button
    if (this.hasAddToCartButtonTarget) {
      this.addToCartButtonTarget.disabled = false
    }

    // Reset quantity to 1 when switching tiers
    if (this.hasInputTarget) {
      this.inputTarget.value = 1
    }

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
    if (!this.selectedPrice) return

    const quantity = parseInt(this.inputTarget.value, 10) || 1
    const total = quantity * this.selectedPrice

    if (this.hasTotalDisplayTarget) {
      this.totalDisplayTarget.textContent = this.formatCurrency(total)
    }

    if (this.hasQuantityInputTarget) {
      this.quantityInputTarget.value = quantity
    }

    if (this.hasUnitsDisplayTarget) {
      const totalUnits = quantity * this.selectedPacSize
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
