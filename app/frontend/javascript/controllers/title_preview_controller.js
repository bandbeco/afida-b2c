import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["size", "colour", "material", "name", "preview"]

  connect() {
    this.update()
  }

  update() {
    const parts = [
      this.sizeTarget.value.trim(),
      this.colourTarget.value.trim(),
      this.materialTarget.value.trim(),
      this.nameTarget.value.trim()
    ].filter(Boolean)

    // Deduplicate case-insensitively (mirrors Ruby's uniq(&:downcase))
    const seen = new Set()
    const unique = parts.filter(part => {
      const lower = part.toLowerCase()
      if (seen.has(lower)) return false
      seen.add(lower)
      return true
    })

    const title = unique.join(" ")
    this.previewTarget.textContent = title || "Enter product details above"
  }
}
