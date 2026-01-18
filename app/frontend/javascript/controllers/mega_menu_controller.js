import { Controller } from "@hotwired/stimulus"

/**
 * Mega menu controller for hover-triggered dropdowns with image preview.
 *
 * Handles:
 * - Show/hide on mouse enter/leave with delay to prevent flickering
 * - Slide-down/slide-up animation with backdrop overlay
 * - Image preview that changes when hovering over menu items
 * - Keyboard accessibility (Escape to close)
 *
 * Usage:
 *   <div data-controller="mega-menu">
 *     <button data-mega-menu-target="trigger">Collections</button>
 *     <div data-mega-menu-target="backdrop"></div>
 *     <div data-mega-menu-target="panel">
 *       <a data-mega-menu-target="item" data-image-url="/path/to/image.jpg">Coffee Shops</a>
 *       <img data-mega-menu-target="preview" />
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["trigger", "panel", "backdrop", "item", "preview"]
  static values = {
    defaultImage: String
  }

  connect() {
    this.hideTimeout = null
    this.showTimeout = null
    this.isOpen = false

    // Set default image on connect
    if (this.hasPreviewTarget && this.defaultImageValue) {
      this.previewTarget.src = this.defaultImageValue
    }

    // Close on escape key
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.clearTimeouts()
  }

  // Show panel on trigger hover
  showPanel() {
    this.clearTimeouts()
    this.showTimeout = setTimeout(() => {
      this.isOpen = true

      // Show backdrop
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("hidden")
        // Force reflow before adding opacity
        this.backdropTarget.offsetHeight
        this.backdropTarget.classList.add("opacity-100")
      }

      // Show panel with slide-down + fade-in effect
      this.panelTarget.classList.remove("hidden")
      // Force reflow before adding animation classes
      this.panelTarget.offsetHeight
      this.panelTarget.classList.remove("opacity-0", "-translate-y-3")
      this.panelTarget.classList.add("opacity-100", "translate-y-0")
    }, 50) // Small delay to prevent accidental triggers
  }

  // Hide panel when mouse leaves the entire menu area
  hidePanel() {
    this.clearTimeouts()
    this.hideTimeout = setTimeout(() => {
      this.isOpen = false

      // Hide backdrop
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("opacity-100")
      }

      // Hide panel with slide-up + fade-out effect
      this.panelTarget.classList.remove("opacity-100", "translate-y-0")
      this.panelTarget.classList.add("opacity-0", "-translate-y-3")

      // Wait for transition to complete before hiding
      setTimeout(() => {
        if (!this.isOpen) {
          this.panelTarget.classList.add("hidden")
          if (this.hasBackdropTarget) {
            this.backdropTarget.classList.add("hidden")
          }
        }
      }, 300)
    }, 100) // Delay allows moving mouse from trigger to panel
  }

  // Cancel hide when entering the panel
  cancelHide() {
    this.clearTimeouts()
  }

  // Update preview image when hovering over an item
  updatePreview(event) {
    const imageUrl = event.currentTarget.dataset.imageUrl
    if (imageUrl && this.hasPreviewTarget) {
      this.previewTarget.src = imageUrl
    }
  }

  // Reset to default image when leaving an item
  resetPreview() {
    if (this.hasPreviewTarget && this.defaultImageValue) {
      this.previewTarget.src = this.defaultImageValue
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.hidePanel()
    }
  }

  clearTimeouts() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
    if (this.showTimeout) {
      clearTimeout(this.showTimeout)
      this.showTimeout = null
    }
  }
}
