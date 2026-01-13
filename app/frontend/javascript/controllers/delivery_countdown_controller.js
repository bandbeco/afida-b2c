import { Controller } from "@hotwired/stimulus"

/**
 * Countdown timer to 2pm cutoff for next working day delivery.
 * Amazon-style format: "FREE delivery Tuesday, 14 January. Order within 8 hrs 24 mins."
 */
export default class extends Controller {
  static targets = ["countdown", "deliveryDate"]

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
    const day = now.getDay()
    const hours = now.getHours()

    // If it's a weekday and before 2pm, cutoff is today at 2pm
    if (day >= 1 && day <= 5 && hours < 14) {
      target.setHours(14, 0, 0, 0)
      return target
    }

    // Otherwise, find the next weekday
    let daysToAdd = 1

    if (day === 5) {
      // Friday after 2pm -> Monday
      daysToAdd = 3
    } else if (day === 6) {
      // Saturday -> Monday
      daysToAdd = 2
    } else if (day === 0) {
      // Sunday -> Monday
      daysToAdd = 1
    }

    target.setDate(target.getDate() + daysToAdd)
    target.setHours(14, 0, 0, 0)
    return target
  }

  // Get the delivery date (day after cutoff)
  getDeliveryDate(cutoffTime) {
    const deliveryDate = new Date(cutoffTime)
    deliveryDate.setDate(deliveryDate.getDate() + 1)
    return deliveryDate
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
