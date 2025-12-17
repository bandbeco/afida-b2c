import { Controller } from "@hotwired/stimulus"

// Controller for save address prompt on order confirmation page
// Handles dismissing the prompt when user clicks "No thanks"
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
