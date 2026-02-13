import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker", "text"]

  pickerChanged() {
    this.textTarget.value = this.pickerTarget.value
  }

  textChanged() {
    if (/^#[0-9a-fA-F]{6}$/.test(this.textTarget.value)) {
      this.pickerTarget.value = this.textTarget.value
    }
  }
}
