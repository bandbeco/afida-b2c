import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["variantSku", "priceDisplay", "packSizeDisplay", "quantitySelect", "submitButton"]
  static values = { variantsData: Array }

  connect() {
    this.selectedOptions = {}

    if (this.hasVariantsDataValue && this.variantsDataValue.length > 0) {
      // Single variant: auto-select it
      if (this.variantsDataValue.length === 1) {
        this.currentVariant = this.variantsDataValue[0]
        if (this.currentVariant.option_values) {
          this.selectedOptions = { ...this.currentVariant.option_values }
        }
        this.updatePrice()
      } else {
        // Multi-variant: no pre-selection, user must choose
        this.currentVariant = null
        this.updateSubmitButtonState()
      }
    }
  }

  selectOption(event) {
    const button = event.currentTarget
    const optionName = button.dataset.option
    const value = button.dataset.value

    // Update selected options
    this.selectedOptions[optionName] = value

    // Update UI: Remove selection from all buttons in this option group
    const targetName = optionName.toLowerCase() + "Button"
    const buttons = this.element.querySelectorAll(`[data-quick-add-form-target="${targetName}"]`)

    buttons.forEach(btn => {
      btn.classList.remove('border-primary')
      const checkmark = btn.querySelector('.option-checkmark')
      if (checkmark) {
        checkmark.classList.add('hidden')
      }
    })

    // Add selection to clicked button
    button.classList.add('border-primary')
    let checkmark = button.querySelector('.option-checkmark')
    if (!checkmark) {
      // Create checkmark if it doesn't exist
      checkmark = document.createElement('span')
      checkmark.className = 'option-checkmark absolute -top-2 -right-2 w-5 h-5 bg-primary rounded-full flex items-center justify-center'
      checkmark.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-white" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
        </svg>
      `
      button.appendChild(checkmark)
    } else {
      checkmark.classList.remove('hidden')
    }

    // Find matching variant based on all selected options
    this.updateVariantFromOptions()
  }

  updateVariantFromOptions() {
    // Find variant that matches all selected options
    const matchingVariant = this.variantsDataValue.find(variant => {
      if (!variant.option_values) return false

      return Object.keys(this.selectedOptions).every(optionName => {
        return variant.option_values[optionName] === this.selectedOptions[optionName]
      })
    })

    if (!matchingVariant) {
      console.error('No matching variant found for options:', this.selectedOptions)
      return
    }

    this.currentVariant = matchingVariant
    this.variantSkuTarget.value = matchingVariant.sku

    // Update pack size and quantity options if needed
    if (this.hasPackSizeDisplayTarget && this.hasQuantitySelectTarget) {
      this.updateQuantityOptions()
    }

    // Update price and submit button state
    this.updatePrice()
    this.updateSubmitButtonState()
  }

  updatePrice() {
    if (!this.hasPriceDisplayTarget || !this.currentVariant) return

    // Get selected quantity (value is number of packs, not units)
    const packs = this.hasQuantitySelectTarget ?
                  parseInt(this.quantitySelectTarget.value) :
                  1

    // Validate data
    const price = this.currentVariant.price || 0

    // Calculate price (packs × price per pack)
    const totalPrice = price * packs

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
    select.innerHTML = ''

    for (let n = 1; n <= 10; n++) {
      const totalUnits = n * pacSize
      const option = document.createElement('option')
      option.value = n  // Value is number of packs, not units
      option.textContent = `${n} ${n === 1 ? 'pack' : 'packs'} (${this.formatNumber(totalUnits)} units)`
      select.appendChild(option)
    }

    // Default to 1 pack
    select.value = 1
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

  updateSubmitButtonState() {
    if (!this.hasSubmitButtonTarget) return

    // Enable submit only when a variant is selected
    if (this.currentVariant) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('btn-disabled')
    } else {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('btn-disabled')
    }
  }
}
