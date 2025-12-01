import { Controller } from "@hotwired/stimulus"

/**
 * Auto Dismiss Controller
 * Automatically removes an element after a configurable delay
 *
 * Usage:
 *   <div data-controller="auto-dismiss" data-auto-dismiss-delay-value="3000">
 *     This will disappear after 3 seconds
 *   </div>
 *
 * With slide animation:
 *   <div data-controller="auto-dismiss"
 *        data-auto-dismiss-animation-value="slide-left">
 */
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 3000 },
    animation: { type: String, default: "fade" }
  }

  connect() {
    // Slide in from right if using slide animation
    if (this.animationValue === "slide-left") {
      this.element.style.transform = "translateX(100%)"
      this.element.style.opacity = "0"
      // Force reflow
      this.element.offsetHeight
      this.element.style.transition = "transform 0.3s ease-out, opacity 0.3s ease-out"
      this.element.style.transform = "translateX(0)"
      this.element.style.opacity = "1"
    }

    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.delayValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    if (this.animationValue === "slide-left") {
      // Slide out to the left
      this.element.style.transition = "transform 0.3s ease-in, opacity 0.3s ease-in"
      this.element.style.transform = "translateX(-100%)"
      this.element.style.opacity = "0"
    } else {
      // Default fade out
      this.element.style.transition = "opacity 0.3s ease-out"
      this.element.style.opacity = "0"
    }

    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
