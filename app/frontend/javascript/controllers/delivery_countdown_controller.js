import { Controller } from "@hotwired/stimulus"

/**
 * Live "Order within X hrs Y mins" countdown to the next 2pm dispatch cutoff.
 *
 * All delivery logic (cutoff day, weekends, bank holidays, time zone) lives
 * server-side in DeliveryEstimate. This controller is deliberately dumb: it
 * receives the cutoff instant as an ISO timestamp and just ticks down to it.
 * When the cutoff passes, it reloads so the server recomputes the next one
 * (and the displayed delivery date) rather than duplicating that logic here.
 */
export default class extends Controller {
  static targets = ["countdown"]
  static values = { cutoffAt: String }

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  update() {
    const diff = new Date(this.cutoffAtValue) - new Date()

    // Cutoff has passed: reload so the server recomputes the next cutoff and
    // the delivery date. `replace` avoids polluting the browser history.
    if (diff <= 0) {
      clearInterval(this.timer)
      Turbo.visit(window.location.href, { action: "replace" })
      return
    }

    const hours = Math.floor(diff / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))

    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent =
        hours > 0 ? `${hours} hrs ${minutes} mins` : `${minutes} mins`
    }
  }
}
