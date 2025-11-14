import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["product", "variant", "targetSlug", "variantParams"]

  connect() {
    // Initialize variant dropdown based on current product selection
    if (this.productTarget.value) {
      this.loadVariants()
    }
  }

  async loadVariants() {
    const productSlug = this.productTarget.value

    if (!productSlug) {
      this.variantTarget.innerHTML = '<option value="">Select a product first</option>'
      this.variantTarget.disabled = true
      return
    }

    // Show loading state
    this.variantTarget.innerHTML = '<option value="">Loading variants...</option>'
    this.variantTarget.disabled = true

    try {
      const response = await fetch(`/admin/products/${productSlug}/variants.json`)

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()

      if (!data.variants || data.variants.length === 0) {
        this.variantTarget.innerHTML = '<option value="">No variants available</option>'
        this.variantTarget.disabled = true
        this.showError('This product has no active variants')
        return
      }

      this.variantTarget.innerHTML = '<option value="">Select variant...</option>'

      data.variants.forEach(variant => {
        const option = document.createElement('option')
        option.value = JSON.stringify({
          id: variant.id,
          slug: data.product.slug,
          params: variant.option_values
        })
        option.textContent = variant.display_name || variant.name
        this.variantTarget.appendChild(option)
      })

      this.variantTarget.disabled = false

      // Try to restore previously selected variant
      this.restoreVariantSelection()

    } catch (error) {
      console.error('Failed to load variants:', error)
      this.variantTarget.innerHTML = '<option value="">Error loading variants</option>'
      this.variantTarget.disabled = true
      this.showError(`Failed to load variants: ${error.message}`)
    }
  }

  showError(message) {
    // Create or update alert banner
    let alert = document.getElementById('variant-load-error')
    if (!alert) {
      alert = document.createElement('div')
      alert.id = 'variant-load-error'
      alert.className = 'alert alert-error mb-4'
      this.element.insertBefore(alert, this.element.firstChild)
    }
    alert.textContent = message

    // Auto-dismiss after 5 seconds
    setTimeout(() => alert.remove(), 5000)
  }

  variantSelected() {
    const selectedOption = this.variantTarget.value

    if (!selectedOption) {
      this.targetSlugTarget.value = ''
      this.variantParamsTarget.value = '{}'
      return
    }

    try {
      const data = JSON.parse(selectedOption)
      this.targetSlugTarget.value = data.slug
      this.variantParamsTarget.value = JSON.stringify(data.params)
    } catch (error) {
      console.error('Failed to parse variant data:', error)
    }
  }

  restoreVariantSelection() {
    // Try to match the current variant params to restore selection
    const currentParams = this.variantParamsTarget.value

    if (!currentParams || currentParams === '{}' || currentParams === '') return

    let currentParamsObj
    try {
      currentParamsObj = JSON.parse(currentParams)
    } catch (e) {
      console.error('Failed to parse current variant params:', e)
      return
    }

    // Match by comparing actual object properties (subset matching)
    for (let option of this.variantTarget.options) {
      if (!option.value) continue

      try {
        const data = JSON.parse(option.value)

        // Check if stored params match variant params (variant may have more keys)
        if (this.objectsEqual(data.params, currentParamsObj)) {
          option.selected = true
          break
        }
      } catch (e) {
        // Skip invalid options
      }
    }
  }

  // Helper method to check if stored params (obj2) match variant params (obj1)
  // obj1 (variant) may have more keys than obj2 (stored), but all obj2 keys must match
  objectsEqual(variantParams, storedParams) {
    const storedKeys = Object.keys(storedParams || {})

    // Check if all stored params exist in variant params with same values
    return storedKeys.every(key => variantParams[key] === storedParams[key])
  }
}
