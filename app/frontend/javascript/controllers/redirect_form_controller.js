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

    if (!currentParams || currentParams === '{}') return

    for (let option of this.variantTarget.options) {
      if (!option.value) continue

      try {
        const data = JSON.parse(option.value)
        if (JSON.stringify(data.params) === currentParams) {
          option.selected = true
          break
        }
      } catch (e) {
        // Skip invalid options
      }
    }
  }
}
