import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }
  static targets = ["banner"]

  connect() {
    if (this.isDismissed) return
    this.bannerTarget.classList.remove("hidden")
  }

  dismiss() {
    this.bannerTarget.classList.add("hidden")
    localStorage.setItem(this.storageKey, "true")
  }

  get isDismissed() {
    return localStorage.getItem(this.storageKey) === "true"
  }

  get storageKey() {
    return `banner-dismissed-${this.keyValue}`
  }
}
