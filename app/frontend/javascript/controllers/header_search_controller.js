import { Controller } from "@hotwired/stimulus"

// Header search controller - handles search input and dropdown visibility
//
// Features:
// - Debounced search (200ms delay)
// - Dropdown shows/hides on focus/blur
// - Mobile toggle for search input visibility
// - Turbo Frame integration for live results
//
// Targets:
// - container: The search input wrapper (for mobile toggle)
// - input: The search text input
// - results: The dropdown results container
//
export default class extends Controller {
  static targets = ["container", "input", "results"]

  connect() {
    this.debounceTimeout = null
    this.hideTimeout = null
  }

  disconnect() {
    if (this.debounceTimeout) clearTimeout(this.debounceTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
  }

  // Toggle search visibility on mobile
  toggle() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.toggle("hidden")
      if (!this.containerTarget.classList.contains("hidden") && this.hasInputTarget) {
        this.inputTarget.focus()
      }
    }
  }

  // Debounced search - waits 200ms after typing stops
  search() {
    if (this.debounceTimeout) clearTimeout(this.debounceTimeout)

    this.debounceTimeout = setTimeout(() => {
      this.performSearch()
    }, 200)
  }

  // Actually perform the search via Turbo Frame
  performSearch() {
    if (!this.hasInputTarget) return

    const query = this.inputTarget.value.trim()

    if (query.length >= 2) {
      // Fetch results via Turbo Frame
      const frame = document.getElementById("header-search-results")
      if (frame) {
        frame.src = `/search?q=${encodeURIComponent(query)}`
        this.showResults()
      }
    } else {
      // Clear results for short queries by reloading empty frame
      const frame = document.getElementById("header-search-results")
      if (frame) {
        frame.textContent = ""
      }
      this.hideResults()
    }
  }

  // Show results dropdown
  showResults() {
    if (this.hideTimeout) clearTimeout(this.hideTimeout)

    if (this.hasResultsTarget && this.hasInputTarget && this.inputTarget.value.trim().length >= 2) {
      this.resultsTarget.classList.remove("hidden")
    }
  }

  // Hide results with delay (allows clicking results)
  hideResultsDelayed() {
    this.hideTimeout = setTimeout(() => {
      this.hideResults()
    }, 200)
  }

  // Immediately hide results
  hideResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("hidden")
    }
  }
}
