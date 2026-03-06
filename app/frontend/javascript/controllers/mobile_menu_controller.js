import { Controller } from "@hotwired/stimulus"

/**
 * Mobile drill-down menu controller.
 *
 * Opens a slide-in panel with top-level categories.
 * Tapping a category with subcategories drills down to a subcategory panel.
 * Back button returns to the top-level list.
 */
export default class extends Controller {
  static targets = ["panel", "backdrop", "topLevel", "subcategoryPanel"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  open() {
    // Show backdrop
    this.backdropTarget.classList.remove("hidden")
    this.backdropTarget.offsetHeight // force reflow
    this.backdropTarget.classList.remove("opacity-0")
    this.backdropTarget.classList.add("opacity-100")

    // Slide in panel
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.classList.add("translate-x-0")

    // Prevent body scroll
    document.body.classList.add("overflow-hidden")
  }

  close() {
    // Slide out panel
    this.panelTarget.classList.remove("translate-x-0")
    this.panelTarget.classList.add("-translate-x-full")

    // Hide backdrop
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    setTimeout(() => {
      this.backdropTarget.classList.add("hidden")
    }, 300)

    // Reset to top-level view
    this.resetToTopLevel()

    // Restore body scroll
    document.body.classList.remove("overflow-hidden")
  }

  drillDown(event) {
    const slug = event.currentTarget.dataset.categorySlug

    // Hide top-level list
    this.topLevelTarget.classList.add("hidden")

    // Show matching subcategory panel
    const panel = this.subcategoryPanelTargets.find(p => p.dataset.category === slug)
    if (panel) {
      panel.classList.remove("hidden")
    }
  }

  goBack() {
    // Hide all subcategory panels
    this.subcategoryPanelTargets.forEach(p => p.classList.add("hidden"))

    // Show top-level list
    this.topLevelTarget.classList.remove("hidden")
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  resetToTopLevel() {
    this.subcategoryPanelTargets.forEach(p => p.classList.add("hidden"))
    this.topLevelTarget.classList.remove("hidden")
  }
}
