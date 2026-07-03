import { Controller } from "@hotwired/stimulus"

// Search modal controller
// Opens a full-screen modal with search input, quick search chips, and category cards.
// Results replace default content when user types.
export default class extends Controller {
  static targets = [
    "modal", "content", "input", "defaultContent", "results",
    "recentSearches", "recentSearchesList", "quickChip"
  ]
  static values = { debounce: { type: Number, default: 200 } }

  // localStorage key and cap for the recent-searches history (issue #251).
  static RECENT_KEY = "afida:recentSearches"
  static RECENT_MAX = 5

  connect() {
    this.previouslyFocusedElement = null
    this.searchTimeout = null
    // Query awaiting a recent-searches record once the frame confirms results.
    this.pendingRecordQuery = null
    // Index of the keyboard-selected result row (-1 = nothing selected).
    this.activeIndex = -1

    // Store bound function references
    this.boundHandleEscape = this.handleEscape.bind(this)
    this.boundTrapFocus = this.trapFocus.bind(this)
    this.boundOpenFromEvent = this.openFromEvent.bind(this)
    this.boundHandleShortcut = this.handleShortcut.bind(this)

    // Listen for global open event (from navbar button)
    window.addEventListener("search-modal:open", this.boundOpenFromEvent)
    // Cmd+K / Ctrl+K opens search from anywhere on the page.
    document.addEventListener("keydown", this.boundHandleShortcut)
  }

  disconnect() {
    this.clearSearchTimeout()
    document.removeEventListener("keydown", this.boundHandleEscape)
    document.removeEventListener("keydown", this.boundHandleShortcut)
    this.element.removeEventListener("keydown", this.boundTrapFocus)
    window.removeEventListener("search-modal:open", this.boundOpenFromEvent)
  }

  // Cmd+K (mac) / Ctrl+K (win/linux) toggles the search modal open.
  handleShortcut(event) {
    if ((event.metaKey || event.ctrlKey) && event.key?.toLowerCase() === "k") {
      event.preventDefault()
      if (this.modalTarget.classList.contains("hidden")) {
        this.open()
      } else {
        this.inputTarget.focus()
      }
    }
  }

  // Called from global event (navbar button click)
  openFromEvent(event) {
    this.open(event)
  }

  open(event) {
    event?.preventDefault()

    // Store previously focused element for restoration
    this.previouslyFocusedElement = document.activeElement

    // Show modal
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")

    // Focus search input
    requestAnimationFrame(() => {
      this.inputTarget.focus()
    })

    // Refresh the recent-searches list from localStorage.
    this.renderRecentSearches()

    // Set up event listeners
    document.addEventListener("keydown", this.boundHandleEscape)
    this.element.addEventListener("keydown", this.boundTrapFocus)
  }

  close(event) {
    event?.preventDefault()

    // Hide modal
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")

    // Clear search and show default content
    this.inputTarget.value = ""
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.clearActiveSelection()
    this.showDefaultContent()

    // Restore focus
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }

    // Remove event listeners
    document.removeEventListener("keydown", this.boundHandleEscape)
    this.element.removeEventListener("keydown", this.boundTrapFocus)
  }

  // Handle clicking overlay to close (only if clicking the backdrop, not the content)
  closeOnOverlay(event) {
    // Only close if clicking directly on the modal backdrop (not its children)
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  // Handle ESC key
  handleEscape(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  // Debounced search
  search() {
    this.clearSearchTimeout()

    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.showDefaultContent()
      return
    }

    this.searchTimeout = setTimeout(() => {
      // A typed query is eligible for recent-searches history; a curated or
      // recent chip (quickSearch) is not, so it does not echo back into recents.
      this.performSearch(query, { record: true })
    }, this.debounceValue)
  }

  performSearch(query, { record = false } = {}) {
    // A new query invalidates any keyboard selection from the old result set.
    this.clearActiveSelection()

    // Defer recording until the frame confirms results exist (resultsLoaded),
    // so zero-result typos never land in history (issue #251 follow-up).
    this.pendingRecordQuery = record ? query : null

    // Update Turbo Frame src to trigger search
    const frame = this.resultsTarget
    const url = `/search?q=${encodeURIComponent(query)}&modal=true`
    frame.src = url

    // Show results, hide default content
    this.showResults()
  }

  // Fires after the results Turbo Frame swaps in new content. Records the query
  // into recent-searches only when it was typed (not a curated/recent chip) and
  // actually returned at least one result row, keeping the history clean.
  resultsLoaded() {
    const query = this.pendingRecordQuery
    this.pendingRecordQuery = null
    if (!query) return

    const hasResults = this.hasResultsTarget &&
      this.resultsTarget.querySelector('[role="option"]') !== null
    if (hasResults) this.recordRecentSearch(query)
  }

  // Enter opens the keyboard-selected result row when there is one, otherwise
  // it navigates to the full results page with the current query (issues #249
  // and #250). Guards the minimum 2-character rule for the fallback.
  submit(event) {
    const active = this.activeOption()
    if (active) {
      event.preventDefault()
      this.primaryLinkFor(active)?.click()
      return
    }

    const query = this.inputTarget.value.trim()
    if (query.length < 2) return

    event.preventDefault()
    window.location.href = `/shop?q=${encodeURIComponent(query)}`
  }

  // Each result row is an inert div[role="option"] whose primary action is its
  // heading link, so its size chips can be their own links without nesting
  // anchors. A click anywhere on the row background delegates to that heading
  // link (reusing its Turbo _top navigation), while a click that lands on an
  // inner link (heading or size chip) is left to navigate on its own (#247).
  navigateRow(event) {
    if (event.target.closest("a")) return

    this.primaryLinkFor(event.currentTarget)?.click()
  }

  // The heading link of a result-row option, used for both row-background
  // clicks and keyboard Enter.
  primaryLinkFor(option) {
    return option.querySelector("[data-search-primary-link]")
  }

  // Arrow down moves the selection to the next result row (issue #250).
  next(event) {
    const options = this.optionElements()
    if (options.length === 0) return

    event.preventDefault()
    this.activeIndex = (this.activeIndex + 1) % options.length
    this.applyActiveSelection(options)
  }

  // Arrow up moves the selection to the previous result row (issue #250).
  previous(event) {
    const options = this.optionElements()
    if (options.length === 0) return

    event.preventDefault()
    this.activeIndex = this.activeIndex <= 0 ? options.length - 1 : this.activeIndex - 1
    this.applyActiveSelection(options)
  }

  // Live list of the current result-row options (re-queried each time because
  // Turbo replaces the frame contents on every search).
  optionElements() {
    if (!this.hasResultsTarget) return []
    return Array.from(this.resultsTarget.querySelectorAll('[role="option"]'))
  }

  // The currently keyboard-selected option element, or null.
  activeOption() {
    const options = this.optionElements()
    if (this.activeIndex < 0 || this.activeIndex >= options.length) return null
    return options[this.activeIndex]
  }

  applyActiveSelection(options) {
    options.forEach((option, index) => {
      const selected = index === this.activeIndex
      option.setAttribute("aria-selected", selected ? "true" : "false")
      // Toggle the highlight classes directly, matching the pricing-tier and
      // configurator selectors (Tailwind aria variants are not relied on here).
      option.classList.toggle("border-primary", selected)
      option.classList.toggle("bg-primary/5", selected)
      option.classList.toggle("border-gray-100", !selected)
    })

    const active = options[this.activeIndex]
    if (active) {
      this.inputTarget.setAttribute("aria-activedescendant", active.id)
      active.scrollIntoView({ block: "nearest" })
    }
  }

  clearActiveSelection() {
    this.activeIndex = -1
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.optionElements().forEach((option) => {
      option.setAttribute("aria-selected", "false")
      option.classList.remove("border-primary", "bg-primary/5")
      option.classList.add("border-gray-100")
    })
  }

  // Quick search chip clicked (Most searched or a recent search).
  quickSearch(event) {
    event.preventDefault()
    const term = event.currentTarget.dataset.term
    this.inputTarget.value = term
    this.performSearch(term)
  }

  // --- Recent searches (localStorage), issue #251 ---

  readRecentSearches() {
    try {
      const raw = window.localStorage.getItem(this.constructor.RECENT_KEY)
      const parsed = raw ? JSON.parse(raw) : []
      return Array.isArray(parsed) ? parsed : []
    } catch (e) {
      return []
    }
  }

  recordRecentSearch(query) {
    const term = query.trim()
    if (term.length < 2) return

    // Most-recent-first, case-insensitive dedupe, capped.
    const existing = this.readRecentSearches().filter(
      (t) => t.toLowerCase() !== term.toLowerCase()
    )
    const updated = [ term, ...existing ].slice(0, this.constructor.RECENT_MAX)

    try {
      window.localStorage.setItem(this.constructor.RECENT_KEY, JSON.stringify(updated))
    } catch (e) {
      // Ignore storage failures (private mode, quota); the feature is optional.
    }
  }

  clearRecentSearches(event) {
    event?.preventDefault()
    try {
      window.localStorage.removeItem(this.constructor.RECENT_KEY)
    } catch (e) {
      // Ignore.
    }
    this.renderRecentSearches()
  }

  renderRecentSearches() {
    if (!this.hasRecentSearchesTarget || !this.hasRecentSearchesListTarget) return

    const terms = this.readRecentSearches()
    if (terms.length === 0) {
      this.recentSearchesTarget.classList.add("hidden")
      this.recentSearchesListTarget.replaceChildren()
      return
    }

    const chips = terms.map((term) => this.buildQuickChip(term))

    this.recentSearchesListTarget.replaceChildren(...chips)
    this.recentSearchesTarget.classList.remove("hidden")
  }

  // Builds a recent-search chip by cloning a server-rendered "Most searched"
  // chip, so the chip styling lives in one place (the _search_suggestions
  // partial) instead of being duplicated as a class string here. Falls back to
  // a plain button if no quick chip is present to clone.
  buildQuickChip(term) {
    const template = this.hasQuickChipTarget ? this.quickChipTarget : null
    const button = template
      ? template.cloneNode(false)
      : document.createElement("button")
    button.type = "button"
    button.dataset.action = "click->search-modal#quickSearch"
    button.dataset.term = term
    button.textContent = term
    return button
  }

  // Navigate to category (closes modal)
  navigateToCategory(event) {
    // Let the link navigate normally, just close the modal
    this.close()
  }

  showDefaultContent() {
    if (this.hasDefaultContentTarget) {
      this.defaultContentTarget.classList.remove("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("hidden")
      // Clear frame by removing src - Turbo will handle cleanup
      this.resultsTarget.removeAttribute("src")
    }
  }

  showResults() {
    if (this.hasDefaultContentTarget) {
      this.defaultContentTarget.classList.add("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("hidden")
    }
  }

  // Clear input and return to default view
  clearSearch(event) {
    event?.preventDefault()
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.showDefaultContent()
  }

  clearSearchTimeout() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
      this.searchTimeout = null
    }
  }

  // Focus trap for accessibility
  trapFocus(event) {
    if (event.key !== "Tab") return

    const focusableElements = this.modalTarget.querySelectorAll(
      'input, button, [href], [tabindex]:not([tabindex="-1"])'
    )

    if (focusableElements.length === 0) return

    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (event.shiftKey && document.activeElement === firstElement) {
      event.preventDefault()
      lastElement.focus()
    } else if (!event.shiftKey && document.activeElement === lastElement) {
      event.preventDefault()
      firstElement.focus()
    }
  }
}
