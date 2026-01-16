import { Controller } from "@hotwired/stimulus"

/**
 * Discount Signup Controller
 *
 * Handles UX for the email signup discount form:
 * - Shows loading state during form submission
 * - Disables form to prevent double submissions
 */
export default class extends Controller {
  static targets = ["email", "submit", "buttonText", "spinner"]

  submit(event) {
    // Show loading state
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.textContent = "Applying..."
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    if (this.hasEmailTarget) {
      this.emailTarget.disabled = true
    }
  }
}
