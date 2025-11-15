import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.previouslyFocusedElement = null

    // Listen for Turbo Frame load to open modal
    this.element.addEventListener('turbo:frame-load', this.open.bind(this))

    // Listen for form submission completion
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))

    // Listen for ESC key
    document.addEventListener('keydown', this.handleEscape.bind(this))
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleEscape.bind(this))
  }

  open(event) {
    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement

    // Focus first interactive element in modal
    const firstFocusable = this.element.querySelector('select, input, button')
    if (firstFocusable) {
      firstFocusable.focus()
    }

    // Set up focus trap
    this.element.addEventListener('keydown', this.trapFocus.bind(this))
  }

  close() {
    // Clear modal content
    this.element.innerHTML = '<turbo-frame id="quick-add-modal"></turbo-frame>'

    // Restore focus to previously focused element
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }

    // Remove focus trap
    this.element.removeEventListener('keydown', this.trapFocus.bind(this))
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
}
