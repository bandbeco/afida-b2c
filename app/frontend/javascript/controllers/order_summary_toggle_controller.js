import { Controller } from "@hotwired/stimulus"

/**
 * Controller for expanding/collapsing order summary on reorder schedule setup page
 *
 * Usage:
 *   <div data-controller="order-summary-toggle"
 *        data-order-summary-toggle-hidden-class="hidden">
 *     <button data-action="click->order-summary-toggle#toggle">
 *       <span data-order-summary-toggle-target="buttonText">View items</span>
 *       <svg data-order-summary-toggle-target="icon">...</svg>
 *     </button>
 *     <div data-order-summary-toggle-target="content" class="hidden">
 *       <!-- Full order items here -->
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["content", "icon", "buttonText"]
  static classes = ["hidden"]

  connect() {
    // Ensure hidden class is applied on connect
    if (this.hasContentTarget && !this.contentTarget.classList.contains(this.hiddenClass)) {
      this.contentTarget.classList.add(this.hiddenClass)
    }
  }

  toggle() {
    if (!this.hasContentTarget) return

    const isHidden = this.contentTarget.classList.toggle(this.hiddenClass)

    // Rotate chevron icon
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180")
    }

    // Update button text
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.textContent = isHidden ? "View items" : "Hide items"
    }
  }
}
