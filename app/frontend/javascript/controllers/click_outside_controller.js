import { Controller } from "@hotwired/stimulus"

/**
 * Closes a <details> dropdown when clicking outside of it.
 *
 * Usage:
 *   <details data-controller="click-outside" data-click-outside-target="details">
 *     <summary>Toggle</summary>
 *     <div>Dropdown content</div>
 *   </details>
 */
export default class extends Controller {
  static targets = ["details"]

  connect() {
    this.boundClose = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  closeOnClickOutside(event) {
    if (!this.hasDetailsTarget) return
    if (!this.detailsTarget.open) return
    if (this.element.contains(event.target)) return

    this.detailsTarget.removeAttribute("open")
  }
}
