import { Controller } from "@hotwired/stimulus"

/**
 * Controller for the sticky sample counter
 *
 * Handles:
 * - Show/hide counter based on sample count
 * - Update badge and message when count changes
 * - Respond to Turbo Stream updates
 *
 * Usage:
 *   <div data-controller="sample-counter"
 *        data-sample-counter-count-value="3"
 *        data-sample-counter-limit-value="5">
 *     <div data-sample-counter-target="badge">3 / 5</div>
 *     <span data-sample-counter-target="message">samples selected</span>
 *   </div>
 */
export default class extends Controller {
  static targets = ["badge", "message"]
  static values = {
    count: { type: Number, default: 0 },
    limit: { type: Number, default: 5 }
  }

  connect() {
    this.updateVisibility()
  }

  countValueChanged() {
    this.updateVisibility()
    this.updateBadge()
    this.updateMessage()
  }

  updateVisibility() {
    if (this.countValue > 0) {
      this.element.classList.remove("hidden")
    } else {
      this.element.classList.add("hidden")
    }
  }

  updateBadge() {
    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = `${this.countValue} / ${this.limitValue}`

      // Update badge color based on limit
      if (this.countValue >= this.limitValue) {
        this.badgeTarget.classList.remove("badge-secondary")
        this.badgeTarget.classList.add("badge-warning")
      } else {
        this.badgeTarget.classList.remove("badge-warning")
        this.badgeTarget.classList.add("badge-secondary")
      }
    }
  }

  updateMessage() {
    if (this.hasMessageTarget) {
      if (this.countValue >= this.limitValue) {
        this.messageTarget.textContent = "Sample limit reached"
      } else {
        this.messageTarget.textContent = "samples selected"
      }
    }
  }
}
