import { Controller } from "@hotwired/stimulus"

/**
 * Auto Dismiss Controller
 * Automatically removes an element after a configurable delay.
 *
 * Usage:
 *   <div data-controller="auto-dismiss" data-auto-dismiss-delay-value="3000">
 *     This will disappear after 3 seconds
 *   </div>
 *
 * With slide animation ("slide-left" exits left, "slide-right" exits right;
 * both arrive from the right):
 *   <div data-controller="auto-dismiss"
 *        data-auto-dismiss-animation-value="slide-right">
 *
 * Animation is carried by classes from stylesheets/components/auto_dismiss.css,
 * not by assigning element.style: the project forbids inline styles, and that
 * rule does not stop applying because the styles are written from JavaScript.
 */

// Kept in step with the transition durations in auto_dismiss.css, so the node
// is removed only once it has finished animating out.
const REMOVAL_DELAY_MS = 300

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 3000 },
    animation: { type: String, default: "fade" }
  }

  connect() {
    if (this.slideClass) {
      this.element.classList.add(`${this.slideClass}-in`)
    }

    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.delayValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    if (this.removeTimeout) {
      clearTimeout(this.removeTimeout)
    }
  }

  // Null for the default fade, so callers opt into sliding by name.
  get slideClass() {
    if (this.animationValue === "slide-left") return "auto-dismiss-slide"
    if (this.animationValue === "slide-right") return "auto-dismiss-slide-right"
    return null
  }

  dismiss() {
    // Guard against already-removed elements
    if (!this.element.isConnected) return

    if (this.slideClass) {
      this.element.classList.remove(`${this.slideClass}-in`)
      this.element.classList.add(`${this.slideClass}-out`)
    } else {
      this.element.classList.add("auto-dismiss-fade-out")
    }

    this.removeTimeout = setTimeout(() => {
      // Check again before removing (element may have been removed by navigation)
      if (this.element.isConnected) {
        this.element.remove()
      }
    }, REMOVAL_DELAY_MS)
  }
}
