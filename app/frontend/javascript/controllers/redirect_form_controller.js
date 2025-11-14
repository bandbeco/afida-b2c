import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["product", "variant", "targetSlug", "variantParams"]

  connect() {
    console.log('Redirect form controller connected')
    console.log('Product value:', this.productTarget.value)
    console.log('Current variant params:', this.variantParamsTarget.value)

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

    try {
      const response = await fetch(`/admin/products/${productSlug}/variants.json`)
      const data = await response.json()

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
    }
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
    console.log('Restoring variant selection...')
    console.log('Current params string:', currentParams)

    if (!currentParams || currentParams === '{}' || currentParams === '') {
      console.log('No params to restore')
      return
    }

    let currentParamsObj
    try {
      currentParamsObj = JSON.parse(currentParams)
      console.log('Parsed current params:', currentParamsObj)
    } catch (e) {
      console.error('Failed to parse current variant params:', e)
      return
    }

    // Match by comparing actual object properties
    let matchFound = false
    for (let option of this.variantTarget.options) {
      if (!option.value) continue

      try {
        const data = JSON.parse(option.value)
        console.log('Checking option:', data.params, 'against', currentParamsObj)

        // Deep compare the params objects
        if (this.objectsEqual(data.params, currentParamsObj)) {
          console.log('Match found! Selecting option:', option.textContent)
          option.selected = true
          matchFound = true
          break
        }
      } catch (e) {
        // Skip invalid options
      }
    }

    if (!matchFound) {
      console.warn('No matching variant found for params:', currentParamsObj)
    }
  }

  // Helper method to compare two objects for equality
  objectsEqual(obj1, obj2) {
    const keys1 = Object.keys(obj1 || {})
    const keys2 = Object.keys(obj2 || {})

    if (keys1.length !== keys2.length) return false

    return keys1.every(key => obj1[key] === obj2[key])
  }
}
