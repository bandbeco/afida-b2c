import { Controller } from "@hotwired/stimulus"

/**
 * Click-to-open mega-menu for the category navigation bar.
 *
 * Each top-level category has a trigger button and a panel.
 * Clicking a trigger opens its panel (and closes any other open panel).
 * Panels close on: clicking outside, pressing Escape, clicking the same trigger again.
 */
export default class extends Controller {
  static targets = ["trigger", "panel", "backdrop"]

  connect() {
    this.openIndex = null
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  toggle(event) {
    const index = parseInt(event.currentTarget.dataset.index)

    if (this.openIndex === index) {
      this.close()
    } else {
      this.open(index)
    }
  }

  open(index) {
    // Close any currently open panel first
    if (this.openIndex !== null) {
      this.closePanel(this.openIndex)
    }

    this.openIndex = index
    const panel = this.panelTargets[index]
    const trigger = this.triggerTargets[index]

    if (!panel || !trigger) return

    // Show backdrop
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
      this.backdropTarget.offsetHeight // force reflow
      this.backdropTarget.classList.add("opacity-100")
    }

    // Show panel
    panel.classList.remove("hidden")
    panel.offsetHeight // force reflow
    panel.classList.remove("opacity-0", "-translate-y-2")
    panel.classList.add("opacity-100", "translate-y-0")

    // Update ARIA
    trigger.setAttribute("aria-expanded", "true")
  }

  close() {
    if (this.openIndex === null) return

    this.closePanel(this.openIndex)

    // Hide backdrop
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("opacity-100")
      setTimeout(() => {
        if (this.openIndex === null) {
          this.backdropTarget.classList.add("hidden")
        }
      }, 200)
    }

    this.openIndex = null
  }

  closePanel(index) {
    const panel = this.panelTargets[index]
    const trigger = this.triggerTargets[index]

    if (!panel || !trigger) return

    panel.classList.remove("opacity-100", "translate-y-0")
    panel.classList.add("opacity-0", "-translate-y-2")

    setTimeout(() => {
      if (this.openIndex !== index) {
        panel.classList.add("hidden")
      }
    }, 200)

    trigger.setAttribute("aria-expanded", "false")
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.openIndex !== null) {
      const trigger = this.triggerTargets[this.openIndex]
      this.close()
      if (trigger) trigger.focus()
    }
  }
}
