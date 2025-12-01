import { Controller } from "@hotwired/stimulus"

/**
 * Clickable Card Controller
 * Makes an entire card clickable by triggering the button inside it
 *
 * Usage:
 *   <div data-controller="clickable-card" data-action="click->clickable-card#click">
 *     <button data-clickable-card-target="button">Action</button>
 *   </div>
 */
export default class extends Controller {
  static targets = ["button"]

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
}
