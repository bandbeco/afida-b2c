import { Controller } from "@hotwired/stimulus"

// Handles Size/Colour option selection on product pages with button selectors
// Finds matching variant based on selected options
export default class extends Controller {
  static targets = ["sizeButton", "colourButton", "priceDisplay", "unitPriceDisplay", "imageDisplay", "variantSkuInput", "quantitySelect", "packSizeDisplay", "skuDisplay", "addToBasketButton"]

  static values = {
    variants: Array,    // All product variants with their option_values
    pacSize: Number,    // Pack size for current variant
    minPrice: Number,   // Minimum price across all variants
    hasSelection: Boolean  // Whether URL has pre-selected variant
  }

  currentVariant = null

  connect() {
    // Hide SKU initially when nothing is selected
    if (this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.style.display = 'none'
    }

    // Disable add to basket button and show "from" price if no URL selection
    if (!this.hasSelectionValue) {
      this.showFromPrice()
      this.disableAddToBasket()
    }

    // Read URL parameters
    const params = new URLSearchParams(window.location.search)
    const urlSize = params.get('size')
    const urlColour = params.get('colour')

    // Only pre-select if URL parameters are present
    if (urlSize && this.hasSizeButtonTarget) {
      const matchingButton = this.sizeButtonTargets.find(btn =>
        btn.dataset.value === urlSize
      )
      if (matchingButton) {
        this.selectButtonVisual(matchingButton)
      }
    }

    if (urlColour && this.hasColourButtonTarget) {
      const matchingButton = this.colourButtonTargets.find(btn =>
        btn.dataset.value === urlColour
      )
      if (matchingButton) {
        this.selectButtonVisual(matchingButton)
      }
    }

    // Update selection only if URL parameters were provided
    if (urlSize || urlColour) {
      this.updateSelection()
    }
  }

  selectSize(event) {
    // Deselect all size buttons
    this.sizeButtonTargets.forEach(btn => this.deselectButtonVisual(btn))
    // Select clicked button
    this.selectButtonVisual(event.currentTarget)
    // Update variant display
    this.updateSelection()
  }

  selectColour(event) {
    // Deselect all colour buttons
    this.colourButtonTargets.forEach(btn => this.deselectButtonVisual(btn))
    // Select clicked button
    this.selectButtonVisual(event.currentTarget)
    // Update variant display
    this.updateSelection()
  }

  updateQuantity(event) {
    // Recalculate total price when quantity changes
    this.updatePrice()

    // Dispatch event for compatible lids to sync quantity
    const quantity = parseInt(event.target.value)
    this.dispatch('quantity-changed', { detail: { quantity: quantity } })
  }

  selectButtonVisual(button) {
    button.classList.remove('border-gray-300')
    button.classList.add('border-primary')
    // Show checkmark
    const checkmark = button.querySelector('.option-checkmark')
    if (checkmark) {
      checkmark.classList.remove('hidden')
    }
  }

  deselectButtonVisual(button) {
    button.classList.remove('border-primary')
    button.classList.add('border-gray-300')
    // Hide checkmark
    const checkmark = button.querySelector('.option-checkmark')
    if (checkmark) {
      checkmark.classList.add('hidden')
    }
  }

  updateSelection() {
    const selectedSize = this.getSelectedValue(this.sizeButtonTargets)
    const selectedColour = this.getSelectedValue(this.colourButtonTargets)

    // Find matching variant
    const matchingVariant = this.findMatchingVariant(selectedSize, selectedColour)

    if (matchingVariant) {
      this.updateDisplay(matchingVariant)
    } else {
      // No variant matched - hide SKU and other variant-specific info
      this.hideVariantInfo()
    }
  }

  hideVariantInfo() {
    // Hide SKU display when no variant is selected
    if (this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.style.display = 'none'
    }

    // Revert to "from" price display
    this.showFromPrice()

    // Disable add to basket button
    this.disableAddToBasket()
  }

  showFromPrice() {
    // Show "from £x.xx / pack" using minimum price
    if (this.hasUnitPriceDisplayTarget && this.hasMinPriceValue) {
      this.unitPriceDisplayTarget.textContent = `from £${this.minPriceValue.toFixed(2)} / pack`
    }
    if (this.hasPriceDisplayTarget && this.hasMinPriceValue) {
      this.priceDisplayTarget.textContent = `£${this.minPriceValue.toFixed(2)}`
    }
  }

  disableAddToBasket() {
    if (this.hasAddToBasketButtonTarget) {
      this.addToBasketButtonTarget.disabled = true
      this.addToBasketButtonTarget.classList.add('btn-disabled')
    }
  }

  enableAddToBasket() {
    if (this.hasAddToBasketButtonTarget) {
      this.addToBasketButtonTarget.disabled = false
      this.addToBasketButtonTarget.classList.remove('btn-disabled')
    }
  }

  getSelectedValue(buttons) {
    if (!buttons || buttons.length === 0) return null
    const selectedButton = buttons.find(btn =>
      btn.classList.contains('border-primary')
    )
    return selectedButton ? selectedButton.dataset.value : null
  }

  findMatchingVariant(size, colour) {
    return this.variantsValue.find(variant => {
      const sizeMatch = !size || variant.option_values.Size === size
      const colourMatch = !colour || variant.option_values.Colour === colour
      return sizeMatch && colourMatch
    })
  }

  updateDisplay(variant) {
    // Store current variant for price calculations
    this.currentVariant = variant

    // Update pack size for the new variant
    const newPacSize = variant.pac_size || 1
    this.pacSizeValue = newPacSize

    // Update quantity dropdown options with new pack size
    this.updateQuantityOptions(newPacSize)

    // Update pack size display
    if (this.hasPackSizeDisplayTarget) {
      this.packSizeDisplayTarget.textContent = `Pack size: ${this.formatNumber(newPacSize)} units`
    }

    // Update SKU display and make it visible
    if (this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.textContent = `SKU: ${variant.sku}`
      this.skuDisplayTarget.style.display = ''
    }

    // Update price with quantity
    this.updatePrice()

    // Update hidden SKU input for cart form
    if (this.hasVariantSkuInputTarget) {
      this.variantSkuInputTarget.value = variant.sku
    }

    // Enable add to basket button
    this.enableAddToBasket()

    // Update image (show photo or placeholder)
    if (this.hasImageDisplayTarget) {
      if (variant.image_url) {
        // Variant has a photo - ensure we have an img element
        if (this.imageDisplayTarget.tagName === 'IMG') {
          this.imageDisplayTarget.src = variant.image_url
        } else {
          // Replace placeholder div with img
          const img = document.createElement('img')
          img.src = variant.image_url
          img.alt = variant.name || 'Product photo'
          img.className = 'w-full h-full object-cover'
          img.dataset.productOptionsTarget = 'imageDisplay'
          this.imageDisplayTarget.replaceWith(img)
        }
      } else {
        // Variant has no photo - show placeholder
        if (this.imageDisplayTarget.tagName === 'IMG') {
          // Replace img with placeholder div
          const placeholder = this.createPlaceholder()
          this.imageDisplayTarget.replaceWith(placeholder)
        }
        // If already a placeholder div, do nothing
      }
    }

    // Dispatch event for compatible lids controller (note: capitalized key)
    const rawSize = variant.option_values?.Size || variant.name
    const size = this.extractSizeFromName(rawSize)
    if (size) {
      this.dispatch('variant-changed', { detail: { size: size } })
    }

    // Update URL to reflect selection (optional)
    this.updateUrl(variant)
  }

  extractSizeFromName(name) {
    // Extract size like "8oz" from variant name or option (e.g., "8oz" from "8oz/227ml")
    const match = name?.match(/(\d+oz)/i)
    return match ? match[1] : null
  }

  updatePrice() {
    if (!this.hasPriceDisplayTarget || !this.currentVariant) return

    // Format currency
    const formatter = new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP'
    })

    // Update unit price (price per pack)
    if (this.hasUnitPriceDisplayTarget) {
      this.unitPriceDisplayTarget.textContent = `${formatter.format(this.currentVariant.price)} / pack`
    }

    // Get selected quantity in units
    const quantityInUnits = this.hasQuantitySelectTarget
      ? parseInt(this.quantitySelectTarget.value)
      : this.pacSizeValue

    // Calculate number of packs (quantity is in units, price is per pack)
    const numberOfPacks = quantityInUnits / this.pacSizeValue

    // Calculate total price (variant price is per pack)
    const totalPrice = this.currentVariant.price * numberOfPacks

    // Update total price display
    this.priceDisplayTarget.textContent = formatter.format(totalPrice)
  }

  updateUrl(variant) {
    const params = new URLSearchParams(window.location.search)

    // Set size parameter if variant has size (note: capitalized key)
    if (variant.option_values.Size) {
      params.set('size', variant.option_values.Size)
    } else {
      params.delete('size')
    }

    // Set colour parameter if variant has colour (note: capitalized key)
    if (variant.option_values.Colour) {
      params.set('colour', variant.option_values.Colour)
    } else {
      params.delete('colour')
    }

    const newUrl = `${window.location.pathname}?${params.toString()}`
    window.history.replaceState({}, '', newUrl)
  }

  // Regenerate quantity dropdown options when pack size changes
  updateQuantityOptions(pacSize) {
    if (!this.hasQuantitySelectTarget) return

    // Clear existing options
    this.quantitySelectTarget.innerHTML = ''

    // Generate new options: 1-10 packs with correct unit counts
    for (let i = 1; i <= 10; i++) {
      const units = pacSize * i
      const packText = i === 1 ? 'pack' : 'packs'
      const label = `${i} ${packText} (${this.formatNumber(units)} units)`

      const option = document.createElement('option')
      option.value = units
      option.textContent = label

      this.quantitySelectTarget.appendChild(option)
    }

    // Reset to first option (1 pack)
    this.quantitySelectTarget.selectedIndex = 0

    // Trigger price update with new quantity
    this.updatePrice()
  }

  // Format number with commas (e.g., 1000 -> "1,000")
  formatNumber(number) {
    return new Intl.NumberFormat('en-GB').format(number)
  }

  // Create placeholder div for variants without photos
  createPlaceholder() {
    const div = document.createElement('div')
    div.className = 'w-full h-full bg-base-200 flex items-center justify-center'
    div.dataset.productOptionsTarget = 'imageDisplay'
    div.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-1/4 w-1/4 text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
    `
    return div
  }
}
