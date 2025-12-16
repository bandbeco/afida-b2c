import { Controller } from "@hotwired/stimulus"

/**
 * Sign In Modal Controller
 *
 * Handles the sign-in modal that can be triggered from various places
 * (e.g., subscription toggle in cart). Uses Turbo Frames for loading
 * content and manages focus, escape key, and click-outside behavior.
 */
export default class extends Controller {
  connect() {
    this.previouslyFocusedElement = null

    // Store bound function references
    this.boundTrapFocus = this.trapFocus.bind(this)
    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundOpen = this.open.bind(this)

    // Listen for Turbo Frame load to open modal
    this.element.addEventListener('turbo:frame-load', this.boundOpen)

    // Listen for ESC key
    document.addEventListener('keydown', this.boundHandleEscape)
  }

  disconnect() {
    this.element.removeEventListener('turbo:frame-load', this.boundOpen)
    document.removeEventListener('keydown', this.boundHandleEscape)
    this.element.removeEventListener('keydown', this.boundTrapFocus)
  }

  open(event) {
    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement

    // Focus first input in modal
    const firstInput = this.element.querySelector('input[type="email"], input[type="text"]')
    if (firstInput) {
      firstInput.focus()
    }

    // Set up focus trap
    this.element.addEventListener('keydown', this.boundTrapFocus)

    // Add click-outside-to-close handler
    const modal = this.element.querySelector('.modal')
    if (modal) {
      modal.addEventListener('click', this.boundHandleClickOutside)
    }
  }

  close() {
    // Remove click-outside handler
    const modal = this.element.querySelector('.modal')
    if (modal) {
      modal.removeEventListener('click', this.boundHandleClickOutside)
    }

    // Clear modal content safely using DOM methods
    while (this.element.firstChild) {
      this.element.removeChild(this.element.firstChild)
    }

    // Restore focus
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }

    // Remove focus trap
    this.element.removeEventListener('keydown', this.boundTrapFocus)
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      const modal = this.element.querySelector('.modal')
      if (modal && modal.classList.contains('modal-open')) {
        event.preventDefault()
        this.close()
      }
    }
  }

  trapFocus(event) {
    if (event.key !== 'Tab') return

    const focusableElements = this.element.querySelectorAll(
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

  handleClickOutside(event) {
    // Close if clicking directly on modal overlay (not content)
    if (event.target.classList.contains('modal')) {
      event.preventDefault()
      this.close()
    }
  }
}
