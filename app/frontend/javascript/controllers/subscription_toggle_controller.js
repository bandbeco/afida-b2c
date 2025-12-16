import { Controller } from "@hotwired/stimulus"

// Controls the subscription toggle UI in the cart
// Dynamically switches the checkout button between regular and subscription checkout
export default class extends Controller {
  static targets = [
    "toggle",
    "options",
    "helperText",
    "frequencySelect",
    "checkoutForm",
    "checkoutButton",
    "buttonText",
    "frequencyInput"
  ]

  static values = {
    enabled: Boolean,
    checkoutUrl: String,
    subscriptionUrl: String
  }

  connect() {
    this.updateUI()
  }

  toggleSubscription(event) {
    this.enabledValue = event.target.checked
    this.updateUI()
  }

  updateUI() {
    if (this.enabledValue) {
      // Subscription mode: show frequency options, update form
      if (this.hasOptionsTarget) {
        this.optionsTarget.classList.remove("hidden")
      }
      if (this.hasHelperTextTarget) {
        this.helperTextTarget.classList.add("hidden")
      }
      if (this.hasCheckoutFormTarget) {
        this.checkoutFormTarget.action = this.subscriptionUrlValue
      }
      if (this.hasButtonTextTarget) {
        this.buttonTextTarget.textContent = "Subscribe & Checkout"
      }
      // Sync frequency from select to hidden input
      this.syncFrequency()
    } else {
      // Regular checkout mode: hide frequency options, update form
      if (this.hasOptionsTarget) {
        this.optionsTarget.classList.add("hidden")
      }
      if (this.hasHelperTextTarget) {
        this.helperTextTarget.classList.remove("hidden")
      }
      if (this.hasCheckoutFormTarget) {
        this.checkoutFormTarget.action = this.checkoutUrlValue
      }
      if (this.hasButtonTextTarget) {
        this.buttonTextTarget.textContent = "Proceed to Checkout"
      }
    }
  }

  frequencyChanged(event) {
    this.syncFrequency()
  }

  syncFrequency() {
    if (this.hasFrequencySelectTarget && this.hasFrequencyInputTarget) {
      this.frequencyInputTarget.value = this.frequencySelectTarget.value
    }
  }
}
