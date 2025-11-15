import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.previouslyFocusedElement = null

    // Store bound function references to prevent memory leaks
    this.boundTrapFocus = this.trapFocus.bind(this)
    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundOpen = this.open.bind(this)
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)

    // Listen for Turbo Frame load to open modal
    this.element.addEventListener('turbo:frame-load', this.boundOpen)

    // Listen for form submission completion
    this.element.addEventListener('turbo:submit-end', this.boundHandleSubmitEnd)

    // Listen for ESC key
    document.addEventListener('keydown', this.boundHandleEscape)
  }

  disconnect() {
    // Clean up all event listeners
    this.element.removeEventListener('turbo:frame-load', this.boundOpen)
    this.element.removeEventListener('turbo:submit-end', this.boundHandleSubmitEnd)
    document.removeEventListener('keydown', this.boundHandleEscape)
    this.element.removeEventListener('keydown', this.boundTrapFocus)
  }

  open(event) {
    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement

    // Focus first interactive element in modal
    const firstFocusable = this.element.querySelector('select, input, button')
    if (firstFocusable) {
      firstFocusable.focus()
    }

    // Set up focus trap (using stored bound function)
    this.element.addEventListener('keydown', this.boundTrapFocus)

    // Add click-outside-to-close handler
    const modal = this.element.querySelector('.modal')
    if (modal) {
      modal.addEventListener('click', this.boundHandleClickOutside)
    }
  }

  close() {
    // Remove click-outside handler before clearing content
    const modal = this.element.querySelector('.modal')
    if (modal) {
      modal.removeEventListener('click', this.boundHandleClickOutside)
    }

    // Clear modal content
    this.element.innerHTML = '<turbo-frame id="quick-add-modal"></turbo-frame>'

    // Restore focus to previously focused element
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }

    // Remove focus trap (using stored bound function)
    this.element.removeEventListener('keydown', this.boundTrapFocus)
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      // Dispatch custom event for cart drawer to listen
      window.dispatchEvent(new CustomEvent('cart:updated', {
        detail: { source: 'quick_add' }
      }))

      // Close modal
      this.close()
    }
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
      'select, input, button, [href], [tabindex]:not([tabindex="-1"])'
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
    // Only close if clicking directly on the modal overlay (not its children)
    // DaisyUI modals have .modal as overlay and .modal-box as content
    if (event.target.classList.contains('modal')) {
      event.preventDefault()
      this.close()
    }
  }
}
