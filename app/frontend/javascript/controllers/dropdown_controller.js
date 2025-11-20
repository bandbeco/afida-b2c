import { Controller } from "@hotwired/stimulus"

/**
 * Hover-triggered Dropdown Controller
 * Provides hover-based dropdown functionality for navigation menus
 * with support for keyboard accessibility
 */
export default class extends Controller {
  static targets = ["menu"]
  static values = {
    delay: { type: Number, default: 100 }  // Delay before showing/hiding (ms)
  }

  connect() {
    this.hideTimeout = null
    this.showTimeout = null
  }

  disconnect() {
    this.cancelTimeouts()
  }

  // Show dropdown on mouse enter
  show() {
    this.cancelTimeouts()

    this.showTimeout = setTimeout(() => {
      this.menuTarget.classList.remove("hidden")
      this.menuTarget.classList.add("block")
    }, this.delayValue)
  }

  // Hide dropdown on mouse leave
  hide() {
    this.cancelTimeouts()

    this.hideTimeout = setTimeout(() => {
      this.menuTarget.classList.remove("block")
      this.menuTarget.classList.add("hidden")
    }, this.delayValue)
  }

  // Keep dropdown open when mouse enters the menu
  keepOpen() {
    this.cancelTimeouts()
  }

  // Toggle for keyboard/touch users
  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.remove("hidden")
      this.menuTarget.classList.add("block")
    } else {
      this.menuTarget.classList.remove("block")
      this.menuTarget.classList.add("hidden")
    }
  }

  // Close dropdown when clicking outside
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("block")
      this.menuTarget.classList.add("hidden")
    }
  }

  // Helper: Cancel pending timeouts
  cancelTimeouts() {
    if (this.showTimeout) {
      clearTimeout(this.showTimeout)
      this.showTimeout = null
    }
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }
}
