import { Controller } from "@hotwired/stimulus"

/**
 * Countdown timer to 2pm cutoff for next working day delivery.
 * Amazon-style format: "FREE delivery Tuesday, 14 January. Order within 8 hrs 24 mins."
 */
export default class extends Controller {
  static targets = ["countdown", "deliveryDate"]
  static values = { holidays: Array }

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
    const now = new Date()

    // Find the next 2pm cutoff (could be today or a future weekday)
    const cutoffTime = this.getNext2pmCutoff(now)
    const deliveryDate = this.getDeliveryDate(cutoffTime)

    // Update delivery date display
    if (this.hasDeliveryDateTarget) {
      this.deliveryDateTarget.textContent = this.formatDeliveryDate(deliveryDate)
    }

    // Calculate countdown
    const diff = cutoffTime - now
    const hoursLeft = Math.floor(diff / (1000 * 60 * 60))
    const minutesLeft = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))

    // Format countdown (no seconds for cleaner look like Amazon)
    let countdownText
    if (hoursLeft > 0) {
      countdownText = `${hoursLeft} hrs ${minutesLeft} mins`
    } else {
      countdownText = `${minutesLeft} mins`
    }

    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent = countdownText
    }
  }

  // Get the next 2pm cutoff time
  getNext2pmCutoff(now) {
    const target = new Date(now)

    // If today is a working day and we're before 2pm, cutoff is today at 2pm.
    if (this.isWorkingDay(now) && now.getHours() < 14) {
      target.setHours(14, 0, 0, 0)
      return target
    }

    // Otherwise, the cutoff is 2pm on the next working day.
    do {
      target.setDate(target.getDate() + 1)
    } while (!this.isWorkingDay(target))
    target.setHours(14, 0, 0, 0)
    return target
  }

  // Get the delivery date: the next working day after the cutoff. We don't
  // deliver on weekends or UK bank holidays, so skip those.
  getDeliveryDate(cutoffTime) {
    const deliveryDate = new Date(cutoffTime)
    do {
      deliveryDate.setDate(deliveryDate.getDate() + 1)
    } while (!this.isWorkingDay(deliveryDate))
    return deliveryDate
  }

  // A working day is a weekday that isn't a bank holiday.
  isWorkingDay(date) {
    const day = date.getDay()
    if (day === 0 || day === 6) return false

    const iso = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
    return !this.holidaysValue.includes(iso)
  }

  // Format date as "Tuesday, 14 January"
  formatDeliveryDate(date) {
    const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    const months = ["January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"]

    const dayName = days[date.getDay()]
    const dayNum = date.getDate()
    const monthName = months[date.getMonth()]

    return `${dayName}, ${dayNum} ${monthName}`
  }
}
