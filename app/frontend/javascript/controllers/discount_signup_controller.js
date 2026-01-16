import { Controller } from "@hotwired/stimulus"

/**
 * Discount Signup Controller
 *
 * Handles UX for the email signup discount form:
 * - Shows loading state during form submission
 * - Disables button to prevent double submissions
 *
 * Note: We don't disable the email input because disabled fields
 * are excluded from form submission per HTML spec.
 */
export default class extends Controller {
  static targets = ["email", "submit", "buttonText", "spinner"]

  submit(event) {
    // Show loading state - disable only the button, not the input
    // (disabled inputs are not included in form submission)
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.textContent = "Applying..."
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    // Make email input readonly (not disabled) to prevent editing
    // while preserving the value in form submission
    if (this.hasEmailTarget) {
      this.emailTarget.readOnly = true
    }
  }
}
