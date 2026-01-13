import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.toggle()
  }

  toggle() {
    const hasValue = this.inputTarget.value.trim().length > 0
    this.buttonTarget.classList.toggle("hidden", !hasValue)
  }

  clear() {
    this.inputTarget.value = ""
    this.toggle()
    this.inputTarget.focus()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
