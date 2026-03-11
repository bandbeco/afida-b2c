import { Controller } from "@hotwired/stimulus"

/**
 * Hover-to-open mega-menu for the desktop category navigation bar.
 *
 * Each top-level category has a trigger button and a panel.
 * Hovering a trigger opens its panel (and closes any other open panel).
 * Moving the mouse into the panel keeps it open.
 * Panels close on: mouse leaving trigger+panel area or pressing Escape.
 */
export default class extends Controller {
  static targets = ["trigger", "panel"]

  connect() {
    this.openIndex = null
    this.hideTimeout = null
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.clearHideTimeout()
  }

  // Called on mouseenter of a trigger button
  showPanel(event) {
    this.clearHideTimeout()
    const index = parseInt(event.currentTarget.dataset.index)
    if (this.openIndex === index) return
    this.open(index)
  }

  // Called on mouseleave of a trigger button
  scheduleHide() {
    this.clearHideTimeout()
    this.hideTimeout = setTimeout(() => {
      this.close()
    }, 150)
  }

  // Called on mouseenter of a panel — cancel the pending hide
  cancelHide() {
    this.clearHideTimeout()
  }

  // Called on mouseleave of a panel — schedule hide
  panelLeave() {
    this.scheduleHide()
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

    // Position panel horizontally under its trigger
    const triggerRect = trigger.getBoundingClientRect()
    const containerRect = this.element.getBoundingClientRect()
    const panelLeft = triggerRect.left - containerRect.left
    // Ensure panel doesn't overflow the right edge of the viewport
    panel.style.left = `${panelLeft}px`
    panel.style.right = "auto"

    // Show panel
    panel.classList.remove("hidden")
    panel.offsetHeight // force reflow

    // Check if panel overflows right edge and adjust
    const panelRect = panel.getBoundingClientRect()
    if (panelRect.right > window.innerWidth) {
      panel.style.left = "auto"
      panel.style.right = "0px"
    }

    panel.classList.remove("opacity-0")
    panel.classList.add("opacity-100")

    // Update ARIA
    trigger.setAttribute("aria-expanded", "true")
  }

  close() {
    if (this.openIndex === null) return

    this.closePanel(this.openIndex)
    this.openIndex = null

  }

  closePanel(index) {
    const panel = this.panelTargets[index]
    const trigger = this.triggerTargets[index]

    if (!panel || !trigger) return

    panel.classList.remove("opacity-100")
    panel.classList.add("opacity-0")

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

  clearHideTimeout() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }
}
