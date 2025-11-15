import { Controller } from "@hotwired/stimulus"

// Character counter controller for description fields in admin
// Provides real-time word count with color-coded feedback
export default class extends Controller {
  static targets = ["input", "counter"]
  static values = {
    min: Number,
    target: Number,
    max: Number
  }

  connect() {
    // Initial count on page load
    this.count()
  }

  count() {
    const text = this.inputTarget.value.trim()
    const wordCount = text === "" ? 0 : text.split(/\s+/).length

    this.updateDisplay(wordCount)
  }

  updateDisplay(wordCount) {
    // Update counter text
    this.counterTarget.textContent = `${wordCount} words`

    // Remove all color classes first
    this.counterTarget.classList.remove("text-green-600", "text-yellow-600", "text-red-600")

    // Apply color based on thresholds
    if (wordCount >= this.minValue && wordCount <= this.maxValue) {
      // In target range - green
      this.counterTarget.classList.add("text-green-600")
    } else if (wordCount < this.minValue) {
      // Too few - yellow
      this.counterTarget.classList.add("text-yellow-600")
    } else {
      // Too many - red
      this.counterTarget.classList.add("text-red-600")
    }
  }
}
