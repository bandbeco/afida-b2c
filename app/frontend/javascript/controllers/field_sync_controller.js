import { Controller } from "@hotwired/stimulus"

// Two-way value sync between a "mirror" input and the real form input it
// shadows, addressed by the real input's DOM id. Used by the admin Title
// Builder, which surfaces the size-driving dimension fields (length, width,
// height, volume, weight) next to the title for convenience while the real,
// submitting inputs stay in the Specifications section. The mirror has no name
// attribute, so only the real field submits — no double-submission.
//
// Mirror markup:  data-controller="field-sync"
//                 data-field-sync-source-value="product_length_in_mm"
//                 data-action="input->field-sync#push input->title-preview#update"
//
// Editing either input updates the other. The mirror lives inside the
// title-preview controller, so its input event also refreshes the live title
// preview — including when the change originated in the Specifications input,
// because pull() re-dispatches input on the mirror.
export default class extends Controller {
  static values = { source: String }

  connect() {
    this.real = document.getElementById(this.sourceValue)
    if (!this.real) return

    // Seed the mirror from the real input's persisted value on load.
    this.element.value = this.real.value

    // Real -> mirror: keep the mirror current when the same dimension is edited
    // in the Specifications section.
    this.pull = this.pull.bind(this)
    this.real.addEventListener("input", this.pull)
  }

  disconnect() {
    if (this.real && this.pull) this.real.removeEventListener("input", this.pull)
  }

  // Mirror -> real: write the typed value into the submitting input. Guarded so
  // it does not echo when push() itself triggered the real input event.
  push() {
    if (!this.real || this.syncing) return
    this.syncing = true
    this.real.value = this.element.value
    this.real.dispatchEvent(new Event("input", { bubbles: true }))
    this.syncing = false
  }

  // Real -> mirror: copy the value and re-dispatch input on the mirror so the
  // title preview (which only listens inside its own element) refreshes.
  pull() {
    if (this.syncing) return
    this.syncing = true
    this.element.value = this.real.value
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
    this.syncing = false
  }
}
