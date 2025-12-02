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

  // Estimate initial height buffer based on viewport
  // Shows roughly 2 rows of cards while loading; actual height recalculated after load
  static get INITIAL_EXPAND_BUFFER() {
    // Minimum 300px, maximum 600px, or ~40% of viewport height
    return Math.min(600, Math.max(300, Math.round(window.innerHeight * 0.4)))
  }

  connect() {
    // Bind event handlers to this instance
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
    this.handleFrameError = this.handleFrameError.bind(this)
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
        // Listen for frame events
        frame.addEventListener("turbo:frame-load", this.handleFrameLoad, { once: true })
        frame.addEventListener("turbo:frame-missing", this.handleFrameError, { once: true })
        frame.addEventListener("turbo:fetch-request-error", this.handleFrameError, { once: true })
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

  // Handle Turbo Frame load errors (network failures, 404s, etc.)
  handleFrameError(event) {
    console.error("Failed to load category content:", event)

    // Allow retry on next expansion
    this.loadedValue = false

    // Show error message in the frame using safe DOM methods
    if (this.hasContentTarget) {
      const frame = this.contentTarget.querySelector("turbo-frame")
      if (frame) {
        // Clear existing content safely
        frame.replaceChildren()

        // Build error UI with DOM methods
        const container = document.createElement("div")
        container.className = "text-center py-8 text-base-content/60"

        const message = document.createElement("p")
        message.className = "mb-2"
        message.textContent = "Failed to load samples"

        const retryButton = document.createElement("button")
        retryButton.className = "btn btn-sm btn-outline"
        retryButton.textContent = "Try again"
        retryButton.dataset.action = "click->category-expand#retryLoad"

        container.appendChild(message)
        container.appendChild(retryButton)
        frame.appendChild(container)
      }
      // Recalculate height for error message
      requestAnimationFrame(() => {
        this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
      })
    }
  }

  // Retry loading after an error
  retryLoad(event) {
    event.stopPropagation() // Prevent toggle from triggering
    if (this.hasContentTarget) {
      const frame = this.contentTarget.querySelector("turbo-frame")
      if (frame && this.urlValue) {
        // Show loading spinner using safe DOM methods
        frame.replaceChildren()
        const spinnerContainer = document.createElement("div")
        spinnerContainer.className = "flex justify-center py-8"
        const spinner = document.createElement("span")
        spinner.className = "loading loading-spinner loading-md"
        spinnerContainer.appendChild(spinner)
        frame.appendChild(spinnerContainer)

        // Re-attach event listeners and load
        frame.addEventListener("turbo:frame-load", this.handleFrameLoad, { once: true })
        frame.addEventListener("turbo:frame-missing", this.handleFrameError, { once: true })
        frame.addEventListener("turbo:fetch-request-error", this.handleFrameError, { once: true })
        frame.src = this.urlValue
        this.loadedValue = true
      }
    }
  }

  // Cleanup when controller disconnects
  disconnect() {
    if (this.hasContentTarget) {
      const frame = this.contentTarget.querySelector("turbo-frame")
      if (frame) {
        frame.removeEventListener("turbo:frame-load", this.handleFrameLoad)
        frame.removeEventListener("turbo:frame-missing", this.handleFrameError)
        frame.removeEventListener("turbo:fetch-request-error", this.handleFrameError)
      }
    }
  }
}
