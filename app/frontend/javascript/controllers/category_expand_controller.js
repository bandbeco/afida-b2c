import { Controller } from "@hotwired/stimulus"

/**
 * Controller for category expansion on samples page
 *
 * Handles:
 * - Toggle expand/collapse of category variants
 * - Load Turbo Frame content on first expansion
 * - Rotate chevron indicator
 * - Recalculate height after Turbo Frame loads
 *
 * Usage:
 *   <div data-controller="category-expand"
 *        data-category-expand-url-value="/samples/cups"
 *        data-category-expand-category-id-value="123">
 *     <div data-action="click->category-expand#toggle">...</div>
 *     <div data-category-expand-target="content">...</div>
 *     <svg data-category-expand-target="chevron">...</svg>
 *   </div>
 */
export default class extends Controller {
  static targets = ["content", "chevron"]
  static values = {
    url: String,
    categoryId: Number,
    expanded: { type: Boolean, default: false },
    loaded: { type: Boolean, default: false }
  }

  // Temporary height buffer for initial expansion before Turbo Frame loads
  // Provides space for loading spinner; actual height recalculated after load
  static INITIAL_EXPAND_BUFFER = 200

  connect() {
    // Bind the frame load handler to this instance
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
  }

  toggle() {
    if (this.expandedValue) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  expand() {
    // Load content via Turbo Frame if not already loaded
    if (!this.loadedValue && this.hasContentTarget) {
      const frame = this.contentTarget.querySelector("turbo-frame")
      if (frame && this.urlValue) {
        // Listen for this specific frame to finish loading
        frame.addEventListener("turbo:frame-load", this.handleFrameLoad, { once: true })
        frame.src = this.urlValue
        this.loadedValue = true
      }
    }

    // Set initial expanded height (will be recalculated after frame loads)
    if (this.hasContentTarget) {
      this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + this.constructor.INITIAL_EXPAND_BUFFER + "px"
    }

    // Rotate chevron
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.add("rotate-180")
    }

    this.expandedValue = true
  }

  collapse() {
    // Collapse content
    if (this.hasContentTarget) {
      this.contentTarget.style.maxHeight = "0"
    }

    // Reset chevron
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.remove("rotate-180")
    }

    this.expandedValue = false
  }

  // Recalculate height after Turbo Frame loads its content
  handleFrameLoad() {
    if (this.expandedValue && this.hasContentTarget) {
      // Use requestAnimationFrame to ensure DOM has updated
      requestAnimationFrame(() => {
        // Remove maxHeight constraint to let content determine natural height
        // Then set it to actual scrollHeight for smooth animation
        this.contentTarget.style.maxHeight = "none"
        const fullHeight = this.contentTarget.scrollHeight
        this.contentTarget.style.maxHeight = fullHeight + "px"
      })
    }
  }

  // Cleanup when controller disconnects
  disconnect() {
    if (this.hasContentTarget) {
      const frame = this.contentTarget.querySelector("turbo-frame")
      if (frame) {
        frame.removeEventListener("turbo:frame-load", this.handleFrameLoad)
      }
    }
  }
}
