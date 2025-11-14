import { Controller } from "@hotwired/stimulus"

// Simple form controller for auto-submit on change
export default class extends Controller {
  submit(event) {
    // Remove empty parameters before submission for clean URLs
    this.removeEmptyParams()

    // Request submit triggers Turbo to handle the form submission
    this.element.requestSubmit()
  }

  removeEmptyParams() {
    // Find all form inputs
    const inputs = this.element.querySelectorAll('input[type="text"], input[type="search"], select')

    inputs.forEach(input => {
      // Disable inputs with empty values so they don't appear in URL
      if (!input.value || input.value.trim() === '') {
        input.disabled = true
      }
    })

    // Re-enable after a short delay (after form submission)
    setTimeout(() => {
      inputs.forEach(input => {
        input.disabled = false
      })
    }, 100)
  }
}
