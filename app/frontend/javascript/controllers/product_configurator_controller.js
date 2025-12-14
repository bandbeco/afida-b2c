import { Controller } from "@hotwired/stimulus"

// Handles dynamic option selection for consolidated products (e.g., napkins with material + colour)
// Filters available options based on previous selections to prevent invalid combinations
// Supports sparse matrices where not all option combinations exist as variants
export default class extends Controller {
  static targets = [
    "optionGroup",      // Container for each option's buttons
    "optionButton",     // Individual option buttons
    "priceDisplay",
    "unitPriceDisplay",
    "mobilePriceDisplay",
    "imageDisplay",
    "variantSkuInput",
    "quantitySelect",
    "packSizeDisplay",
    "skuDisplay",
    "addToCartButton",
    "form",
    "mobileBar"
  ]

  static values = {
    variants: Array,    // All product variants with their option_values
    optionOrder: Array, // Order of options to display (e.g., ["material", "colour"])
    pacSize: Number,
    minPrice: Number
  }

  // Track current selections
  selections = {}
  currentVariant = null

  connect() {
    // Initialize with nothing selected - show "Price: TBD"
    this.showTbdPrice()
    this.disableAddToCart()

    // Hide SKU initially
    if (this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.style.display = 'none'
    }

    // Check if single variant product (no options needed)
    if (this.variantsValue.length === 1) {
      this.selectVariant(this.variantsValue[0])
      return
    }

    // Initial render of option groups
    this.renderOptionGroups()
  }

  // Render all option groups based on current selections
  renderOptionGroups() {
    this.optionOrderValue.forEach((optionName, index) => {
      const group = this.findOptionGroup(optionName)
      if (!group) return

      // Get available values for this option based on previous selections
      const availableValues = this.getAvailableValuesForOption(optionName)
      const buttons = group.querySelectorAll('[data-option-button]')

      buttons.forEach(button => {
        const value = button.dataset.value
        const isAvailable = availableValues.includes(value)
        const isSelected = this.selections[optionName] === value

        // Update button state
        button.disabled = !isAvailable
        button.classList.toggle('opacity-40', !isAvailable)
        button.classList.toggle('cursor-not-allowed', !isAvailable)
        this.setButtonSelected(button, isSelected)
      })

      // Auto-select if only one option available
      if (availableValues.length === 1 && !this.selections[optionName]) {
        this.selections[optionName] = availableValues[0]
        const singleButton = Array.from(buttons).find(b => b.dataset.value === availableValues[0])
        if (singleButton) {
          this.setButtonSelected(singleButton, true)
        }
      }
    })

    // Check if all options are selected
    this.checkForCompleteSelection()
  }

  // Find the option group element for a given option name
  findOptionGroup(optionName) {
    return this.optionGroupTargets.find(group =>
      group.dataset.optionName === optionName
    )
  }

  // Get available values for an option based on previous selections
  getAvailableValuesForOption(optionName) {
    // Start with all variants
    let filteredVariants = this.variantsValue

    // Filter by all selections made BEFORE this option
    const optionIndex = this.optionOrderValue.indexOf(optionName)
    for (let i = 0; i < optionIndex; i++) {
      const prevOptionName = this.optionOrderValue[i]
      const prevSelection = this.selections[prevOptionName]
      if (prevSelection) {
        filteredVariants = filteredVariants.filter(v =>
          v.option_values[prevOptionName] === prevSelection
        )
      }
    }

    // Extract unique values for this option from filtered variants
    const values = filteredVariants
      .map(v => v.option_values[optionName])
      .filter(v => v != null)
    return [...new Set(values)]
  }

  // Handle option button click
  selectOption(event) {
    const button = event.currentTarget
    const optionName = button.dataset.optionName
    const value = button.dataset.value

    // Skip if button is disabled
    if (button.disabled) return

    // Update selection
    this.selections[optionName] = value

    // Clear selections for options that come AFTER this one
    const optionIndex = this.optionOrderValue.indexOf(optionName)
    for (let i = optionIndex + 1; i < this.optionOrderValue.length; i++) {
      delete this.selections[this.optionOrderValue[i]]
    }

    // Re-render all option groups
    this.renderOptionGroups()
  }

  // Check if all required options are selected
  checkForCompleteSelection() {
    const allSelected = this.optionOrderValue.every(optionName =>
      this.selections[optionName] != null
    )

    if (allSelected) {
      // Find the matching variant
      const variant = this.findMatchingVariant()
      if (variant) {
        this.selectVariant(variant)
      }
    } else {
      // Not all selected - show TBD
      this.showTbdPrice()
      this.disableAddToCart()
      if (this.hasSkuDisplayTarget) {
        this.skuDisplayTarget.style.display = 'none'
      }
    }
  }

  // Find variant matching all current selections
  findMatchingVariant() {
    return this.variantsValue.find(variant => {
      return this.optionOrderValue.every(optionName => {
        const selection = this.selections[optionName]
        return !selection || variant.option_values[optionName] === selection
      })
    })
  }

  // Select a specific variant and update all displays
  selectVariant(variant) {
    this.currentVariant = variant

    // Update pack size
    const newPacSize = variant.pac_size || 1
    this.pacSizeValue = newPacSize
    this.updateQuantityOptions(newPacSize)

    // Update pack size display
    if (this.hasPackSizeDisplayTarget) {
      this.packSizeDisplayTarget.textContent = `Pack size: ${this.formatNumber(newPacSize)} units`
    }

    // Update SKU display
    if (this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.textContent = `SKU: ${variant.sku}`
      this.skuDisplayTarget.style.display = ''
    }

    // Update hidden SKU input
    if (this.hasVariantSkuInputTarget) {
      this.variantSkuInputTarget.value = variant.sku
    }

    // Update price display
    this.updatePrice()

    // Update image if available
    this.updateImage(variant)

    // Enable add to cart
    this.enableAddToCart()

    // Update URL
    this.updateUrl(variant)
  }

  // Hide price displays until variant is selected
  showTbdPrice() {
    if (this.hasPriceDisplayTarget) {
      this.priceDisplayTarget.textContent = 'Price: TBD'
    }
    if (this.hasUnitPriceDisplayTarget) {
      this.unitPriceDisplayTarget.style.display = 'none'
    }
    if (this.hasMobilePriceDisplayTarget) {
      this.mobilePriceDisplayTarget.textContent = 'TBD'
    }
  }

  updatePrice() {
    if (!this.hasPriceDisplayTarget || !this.currentVariant) return

    const formatter = new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP'
    })

    // Calculate unit price (price per individual item)
    const pacSize = this.currentVariant.pac_size || 1
    const unitPrice = this.currentVariant.price / pacSize

    // Format unit price - use more decimal places for small amounts
    const unitPriceFormatted = unitPrice < 1
      ? `${(unitPrice * 100).toFixed(1)}p each`
      : `${formatter.format(unitPrice)} each`

    // Update unit price display (pack price + unit price) and show it
    if (this.hasUnitPriceDisplayTarget) {
      this.unitPriceDisplayTarget.textContent = `${formatter.format(this.currentVariant.price)} (${unitPriceFormatted})`
      this.unitPriceDisplayTarget.style.display = ''
    }

    // Get quantity and calculate total
    const numberOfPacks = this.hasQuantitySelectTarget
      ? parseInt(this.quantitySelectTarget.value)
      : 1
    const totalPrice = this.currentVariant.price * numberOfPacks

    // Update total price display
    this.priceDisplayTarget.textContent = formatter.format(totalPrice)

    // Update mobile price
    if (this.hasMobilePriceDisplayTarget) {
      this.mobilePriceDisplayTarget.textContent = formatter.format(totalPrice)
    }
  }

  updateImage(variant) {
    if (!this.hasImageDisplayTarget) return

    if (variant.image_url) {
      if (this.imageDisplayTarget.tagName === 'IMG') {
        this.imageDisplayTarget.src = variant.image_url
      } else {
        const img = document.createElement('img')
        img.src = variant.image_url
        img.alt = variant.name || 'Product photo'
        img.className = 'w-full h-full object-cover'
        img.dataset.productConfiguratorTarget = 'imageDisplay'
        this.imageDisplayTarget.replaceWith(img)
      }
    }
  }

  updateQuantityOptions(pacSize) {
    if (!this.hasQuantitySelectTarget) return

    // Clear existing options using safe DOM method
    while (this.quantitySelectTarget.firstChild) {
      this.quantitySelectTarget.removeChild(this.quantitySelectTarget.firstChild)
    }

    for (let numPacks = 1; numPacks <= 10; numPacks++) {
      const totalUnits = pacSize * numPacks
      const packText = numPacks === 1 ? 'pack' : 'packs'
      const label = `${numPacks} ${packText} (${this.formatNumber(totalUnits)} units)`

      const option = document.createElement('option')
      option.value = numPacks
      option.textContent = label
      this.quantitySelectTarget.appendChild(option)
    }

    this.quantitySelectTarget.selectedIndex = 0
    this.updatePrice()
  }

  updateQuantity(event) {
    this.updatePrice()
  }

  updateUrl(variant) {
    const params = new URLSearchParams(window.location.search)

    // Set parameters for each option
    this.optionOrderValue.forEach(optionName => {
      const value = variant.option_values[optionName]
      if (value) {
        params.set(optionName, value)
      } else {
        params.delete(optionName)
      }
    })

    const newUrl = `${window.location.pathname}?${params.toString()}`
    window.history.replaceState({}, '', newUrl)
  }

  setButtonSelected(button, selected) {
    if (selected) {
      button.classList.remove('border-gray-300')
      button.classList.add('border-primary')
      const checkmark = button.querySelector('.option-checkmark')
      if (checkmark) checkmark.classList.remove('hidden')
    } else {
      button.classList.remove('border-primary')
      button.classList.add('border-gray-300')
      const checkmark = button.querySelector('.option-checkmark')
      if (checkmark) checkmark.classList.add('hidden')
    }
  }

  disableAddToCart() {
    if (this.hasAddToCartButtonTarget) {
      this.addToCartButtonTarget.disabled = true
      this.addToCartButtonTarget.classList.add('btn-disabled')
    }
  }

  enableAddToCart() {
    if (this.hasAddToCartButtonTarget) {
      this.addToCartButtonTarget.disabled = false
      this.addToCartButtonTarget.classList.remove('btn-disabled')
    }
  }

  submitForm() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  formatNumber(number) {
    return new Intl.NumberFormat('en-GB').format(number)
  }
}
