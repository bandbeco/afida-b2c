import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["variantSku", "variantSelector", "priceDisplay", "packSizeDisplay", "quantitySelect"]
  static values = { variantsData: Array }

  connect() {
    // Initialize with first variant data
    if (this.hasVariantsDataValue && this.variantsDataValue.length > 0) {
      this.currentVariant = this.variantsDataValue[0]
      this.updatePrice()
    }
  }

  updateVariant(event) {
    // Update hidden field with selected variant SKU
    const selectedSku = event.target.value
    this.variantSkuTarget.value = selectedSku

    // Find the selected variant data
    this.currentVariant = this.variantsDataValue.find(v => v.sku === selectedSku)

    // Update pack size display and quantity options
    if (this.currentVariant && this.hasPackSizeDisplayTarget && this.hasQuantitySelectTarget) {
      this.updateQuantityOptions()
    }
  }

  updatePrice() {
    if (!this.hasPriceDisplayTarget || !this.currentVariant) return

    // Get selected quantity
    const quantity = this.hasQuantitySelectTarget ?
                     parseInt(this.quantitySelectTarget.value) :
                     (this.currentVariant.pac_size || 1)

    // Calculate price (quantity is in units, price is per pack)
    const packs = quantity / (this.currentVariant.pac_size || 1)
    const totalPrice = this.currentVariant.price * packs

    // Format and display price
    this.priceDisplayTarget.textContent = this.formatCurrency(totalPrice)
  }

  updateQuantityOptions() {
    if (!this.hasQuantitySelectTarget || !this.currentVariant) return

    const pacSize = this.currentVariant.pac_size || 1

    // Update pack size display
    if (this.hasPackSizeDisplayTarget) {
      this.packSizeDisplayTarget.textContent = `Pack size: ${this.formatNumber(pacSize)} units`
    }

    // Rebuild quantity options
    const select = this.quantitySelectTarget
    const currentValue = parseInt(select.value) || pacSize
    select.innerHTML = ''

    for (let n = 1; n <= 10; n++) {
      const quantityUnits = n * pacSize
      const option = document.createElement('option')
      option.value = quantityUnits
      option.textContent = `${n} ${n === 1 ? 'pack' : 'packs'} (${this.formatNumber(quantityUnits)} units)`
      select.appendChild(option)
    }

    // Try to maintain similar quantity, or default to 1 pack
    select.value = pacSize
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP'
    }).format(amount)
  }

  formatNumber(num) {
    return new Intl.NumberFormat('en-GB').format(num)
  }
}
