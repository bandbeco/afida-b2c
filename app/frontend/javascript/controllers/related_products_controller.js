import { Controller } from "@hotwired/stimulus"

// Handles the related products carousel navigation
export default class extends Controller {
  static targets = ["container"]

  // Scroll the carousel left
  scrollLeft() {
    if (this.hasContainerTarget) {
      this.containerTarget.scrollBy({ left: -300, behavior: 'smooth' })
    }
  }

  // Scroll the carousel right
  scrollRight() {
    if (this.hasContainerTarget) {
      this.containerTarget.scrollBy({ left: 300, behavior: 'smooth' })
    }
  }
}
