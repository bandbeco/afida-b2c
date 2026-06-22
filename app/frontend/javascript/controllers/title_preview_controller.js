import { Controller } from "@hotwired/stimulus"

// Live preview for the admin Title Builder. Posts the current form values to
// Admin::ProductsController#preview_title, which renders Product#generated_title
// and Turbo-Streams it into the preview target. The server is the single source
// of truth, so the preview can never drift from the persisted title (it also
// gets derived_size from the dimension fields for free).
export default class extends Controller {
  static values = { url: String }

  // Fields the preview endpoint reads (mirrors preview_params on the server):
  // the title fields plus the dimension columns derived_size falls back to.
  static FIELDS = [
    "product[brand]",
    "product[size]",
    "product[colour]",
    "product[material]",
    "product[name]",
    "product[length_in_mm]",
    "product[width_in_mm]",
    "product[height_in_mm]",
    "product[weight_in_g]",
    "product[volume_in_ml]"
  ]

  connect() {
    this.update()
  }

  update() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.fetchPreview(), 250)
  }

  async fetchPreview() {
    const form = this.element.closest("form")
    if (!form) return

    const body = new URLSearchParams()
    for (const name of this.constructor.FIELDS) {
      const field = form.elements[name]
      if (field) body.append(name, field.value)
    }

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body
    })

    if (response.ok) {
      Turbo.renderStreamMessage(await response.text())
    }
  }
}
