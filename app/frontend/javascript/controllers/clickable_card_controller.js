import { Controller } from "@hotwired/stimulus"

/**
 * Clickable Card Controller
 * Makes an entire card clickable by triggering the button inside it
 *
 * Accessibility features:
 * - Card is focusable via tabindex
 * - Enter/Space keys trigger the button action
 * - Focus-visible ring for keyboard navigation
 *
 * Usage:
 *   <div data-controller="clickable-card"
 *        data-action="click->clickable-card#click keydown->clickable-card#keydown">
 *     <button data-clickable-card-target="button">Action</button>
 *   </div>
 */
export default class extends Controller {
  static targets = ["button"]

  connect() {
    // Make the card focusable for keyboard navigation
    if (!this.element.hasAttribute("tabindex")) {
      this.element.setAttribute("tabindex", "0")
    }

    // Add focus-visible styles if not already present
    this.element.classList.add("focus-visible:ring-2", "focus-visible:ring-primary", "focus-visible:ring-offset-2", "focus:outline-none")
  }

  click(event) {
    // Don't trigger if clicking on the button itself (avoid double submission)
    if (event.target.closest("button, a, input")) {
      return
    }

    // Find and click the button
    if (this.hasButtonTarget) {
      this.buttonTarget.click()
    }
  }

  keydown(event) {
    // Trigger button on Enter or Space (standard button behavior)
    if (event.key === "Enter" || event.key === " ") {
      // Don't trigger if focus is on the button itself
      if (event.target.closest("button, a, input")) {
        return
      }

      event.preventDefault()
      if (this.hasButtonTarget) {
        this.buttonTarget.click()
      }
    }
  }
}
