import { Controller } from "@hotwired/stimulus"

/**
 * Slide In Controller
 * Provides staggered slide-in animation for text elements using CSS animations
 */
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.animateItems()
  }

  animateItems() {
    // Add animation class with staggered delay to each item
    this.itemTargets.forEach((item, index) => {
      // Set staggered delay for each item
      item.style.animationDelay = `${0.3 + (index * 0.15)}s`
      // Add animation class
      item.classList.add("slide-in-from-top")
    })
  }
}

