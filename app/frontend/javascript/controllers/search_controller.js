import { Controller } from "@hotwired/stimulus"

// Search controller with debouncing to avoid excessive server requests
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  debounce(event) {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      // Remove empty parameters before submission
      this.removeEmptyParams()

      // Submit the form (Turbo will handle it)
      this.element.form.requestSubmit()
    }, this.delayValue)
  }

  removeEmptyParams() {
    const form = this.element.form
    const inputs = form.querySelectorAll('input[type="text"], input[type="search"], select')

    inputs.forEach(input => {
      // Temporarily disable inputs with empty values so they don't appear in URL
      if (!input.value || input.value.trim() === '') {
        input.disabled = true
      }
    })

    // Re-enable after submission
    setTimeout(() => {
      inputs.forEach(input => {
        input.disabled = false
      })
    }, 100)
  }

  disconnect() {
    // Clean up timeout on controller disconnect
    clearTimeout(this.timeout)
  }
}
