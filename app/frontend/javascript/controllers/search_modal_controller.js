import { Controller } from "@hotwired/stimulus"

// Search modal controller
// Opens a full-screen modal with search input, quick search chips, and category cards.
// Results replace default content when user types.
export default class extends Controller {
  static targets = ["modal", "content", "input", "defaultContent", "results"]
  static values = { debounce: { type: Number, default: 200 } }

  connect() {
    this.previouslyFocusedElement = null
    this.searchTimeout = null

    // Store bound function references
    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundTrapFocus = this.trapFocus.bind(this)
    this.boundOpenFromEvent = this.openFromEvent.bind(this)

    // Listen for global open event (from navbar button)
    window.addEventListener("search-modal:open", this.boundOpenFromEvent)
  }

  disconnect() {
    this.clearSearchTimeout()
    document.removeEventListener("keydown", this.boundHandleEscape)
    this.element.removeEventListener("keydown", this.boundTrapFocus)
    window.removeEventListener("search-modal:open", this.boundOpenFromEvent)
  }

  // Called from global event (navbar button click)
  openFromEvent(event) {
    this.open(event)
  }

  open(event) {
    event?.preventDefault()

    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement

    // Show modal
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")

    // Focus search input
    requestAnimationFrame(() => {
      this.inputTarget.focus()
    })

    // Set up event listeners
    document.addEventListener("keydown", this.boundHandleEscape)
    this.element.addEventListener("keydown", this.boundTrapFocus)
  }

  close(event) {
    event?.preventDefault()

    // Hide modal
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")

    // Clear search and show default content
    this.inputTarget.value = ""
    this.showDefaultContent()

    // Restore focus
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }

    // Remove event listeners
    document.removeEventListener("keydown", this.boundHandleEscape)
    this.element.removeEventListener("keydown", this.boundTrapFocus)
  }

  // Handle clicking overlay to close (only if clicking the backdrop, not the content)
  closeOnOverlay(event) {
    // Only close if clicking directly on the modal backdrop (not its children)
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  // Handle ESC key
  handleEscape(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  // Debounced search
  search() {
    this.clearSearchTimeout()

    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.showDefaultContent()
      return
    }

    this.searchTimeout = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceValue)
  }

  performSearch(query) {
    // Update Turbo Frame src to trigger search
    const frame = this.resultsTarget
    const url = `/search?q=${encodeURIComponent(query)}&modal=true`
    frame.src = url

    // Show results, hide default content
    this.showResults()
  }

  // Quick search chip clicked
  quickSearch(event) {
    event.preventDefault()
    const term = event.currentTarget.dataset.term
    this.inputTarget.value = term
    this.performSearch(term)
  }

  // Navigate to category (closes modal)
  navigateToCategory(event) {
    // Let the link navigate normally, just close the modal
    this.close()
  }

  showDefaultContent() {
    if (this.hasDefaultContentTarget) {
      this.defaultContentTarget.classList.remove("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("hidden")
      // Clear frame by removing src - Turbo will handle cleanup
      this.resultsTarget.removeAttribute("src")
    }
  }

  showResults() {
    if (this.hasDefaultContentTarget) {
      this.defaultContentTarget.classList.add("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("hidden")
    }
  }

  // Clear input and return to default view
  clearSearch(event) {
    event?.preventDefault()
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.showDefaultContent()
  }

  clearSearchTimeout() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = null
    }
  }

  // Focus trap for accessibility
  trapFocus(event) {
    if (event.key !== "Tab") return

    const focusableElements = this.modalTarget.querySelectorAll(
      'input, button, [href], [tabindex]:not([tabindex="-1"])'
    )

    if (focusableElements.length === 0) return

    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (event.shiftKey && document.activeElement === firstElement) {
      event.preventDefault()
      lastElement.focus()
    } else if (!event.shiftKey && document.activeElement === lastElement) {
      event.preventDefault()
      firstElement.focus()
    }
  }
}
