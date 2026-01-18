import { Controller } from "@hotwired/stimulus"

/**
 * Mega menu controller for hover-triggered dropdowns with image preview.
 *
 * Handles:
 * - Show/hide on mouse enter/leave with delay to prevent flickering
 * - Image preview that changes when hovering over menu items
 * - Keyboard accessibility (Escape to close)
 *
 * Usage:
 *   <div data-controller="mega-menu">
 *     <button data-mega-menu-target="trigger">Collections</button>
 *     <div data-mega-menu-target="panel">
 *       <a data-mega-menu-target="item" data-image-url="/path/to/image.jpg">Coffee Shops</a>
 *       <img data-mega-menu-target="preview" />
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["trigger", "panel", "item", "preview"]
  static values = {
    defaultImage: String
  }

  connect() {
    this.hideTimeout = null
    this.showTimeout = null

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
      this.panelTarget.classList.remove("hidden", "opacity-0")
      this.panelTarget.classList.add("opacity-100")
    }, 50) // Small delay to prevent accidental triggers
  }

  // Hide panel when mouse leaves the entire menu area
  hidePanel() {
    this.clearTimeouts()
    this.hideTimeout = setTimeout(() => {
      this.panelTarget.classList.add("opacity-0")
      // Wait for transition to complete before hiding
      setTimeout(() => {
        if (this.panelTarget.classList.contains("opacity-0")) {
          this.panelTarget.classList.add("hidden")
        }
      }, 150)
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
    if (event.key === "Escape" && !this.panelTarget.classList.contains("hidden")) {
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
