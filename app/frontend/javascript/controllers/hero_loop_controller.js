import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.currentIndex = 0
    this.showCurrent()
    this.interval = setInterval(() => this.next(), 1000)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }

  next() {
    this.currentIndex = (this.currentIndex + 1) % this.imageTargets.length
    this.showCurrent()
  }

  showCurrent() {
    this.imageTargets.forEach((img, i) => {
      img.classList.toggle("hidden", i !== this.currentIndex)
    })
  }
}
