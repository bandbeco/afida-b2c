import { Controller } from "@hotwired/stimulus"

/**
 * Unified Variant Selector Controller
 * T016: Replaces product_options_controller and product_configurator_controller
 *
 * Features:
 * - Accordion-style option selection with auto-collapse
 * - Option filtering based on available variant combinations
 * - Volume pricing tier cards or quantity dropdown
 * - URL parameter sync for shareable links
 * - Event emission for compatible lids integration
 */
export default class extends Controller {
  static targets = [
    // Option steps
    "step", "stepHeader", "stepIndicator", "stepContent", "stepSelection",
    "optionButton",
    // Quantity step
    "quantityStep", "quantityStepHeader", "quantityStepIndicator",
    "quantityContent", "quantityStepSelection",
    // Display elements
    "imageDisplay", "priceDisplay", "totalDisplay", "mobileTotalDisplay",
    "skuDisplay", "skuValue",
    // Buttons
    "addButton", "mobileAddButton",
    // Form elements
    "form", "variantSkuInput", "quantityInput",
    // Mobile bar
    "mobileBar"
  ]

  static values = {
    variants: Array,
    options: Object,
    priority: { type: Array, default: ["material", "type", "size", "colour"] },
    pacSize: { type: Number, default: 1 },
    minPrice: Number
  }

  connect() {
    this.selections = {}
    this.selectedVariant = null
    this.selectedQuantity = 1
    this.isProcessing = false

    // Load selections from URL params
    this.loadFromUrlParams()

    // Initialize UI state
    this.updateOptionButtons()
    this.updateStepHeaders()

    // Manage step expansion based on URL selections
    // If selections came from URL, we need to override the HTML default (first step open)
    const hasUrlSelections = Object.keys(this.selections).length > 0

    if (this.allOptionsSelected()) {
      // All options selected - collapse all option steps, expand quantity step
      this.collapseAllSteps()
      this.findMatchingVariant()
      this.updateQuantityStep()
      this.expandStep(Object.keys(this.optionsValue).length)
    } else if (hasUrlSelections) {
      // Partial selections from URL - collapse completed steps, expand first incomplete
      this.collapseAllSteps()
      const firstIncompleteIndex = this.getFirstIncompleteStepIndex()
      this.expandStep(firstIncompleteIndex)

      // Try to match a variant if we have partial selections (for image/price updates)
      this.findMatchingVariant()
    }
    // else: no URL selections - HTML default is correct (first step already open)
  }

  /**
   * Handle option button click
   * Includes processing guard to prevent race conditions from rapid double-clicks
   */
  selectOption(event) {
    const button = event.currentTarget

    // Skip if button is disabled or already processing
    if (button.disabled || this.isProcessing) return

    this.isProcessing = true

    try {
      const optionName = button.dataset.optionName
      const value = button.dataset.value

      // Update selection
      this.selections[optionName] = value

      // Clear downstream selections if they're now invalid
      this.clearInvalidDownstreamSelections(optionName)

      // Update UI
      this.updateOptionButtons()
      this.updateStepHeaders()

      // Find matching variant
      this.findMatchingVariant()

      // Collapse current step and expand next
      const currentStepIndex = this.getStepIndex(optionName)
      this.collapseStep(currentStepIndex)

      // If all options selected, show quantity step
      if (this.allOptionsSelected()) {
        this.updateQuantityStep()
        this.expandStep(Object.keys(this.optionsValue).length)
      } else {
        // Expand next option step
        this.expandStep(currentStepIndex + 1)
      }

      // Update URL params
      this.updateUrl()

      // Emit event for compatible lids
      this.emitVariantChanged()
    } finally {
      this.isProcessing = false
    }
  }

  /**
   * Toggle step expansion when clicking header
   */
  toggleStep(event) {
    // Prevent DaisyUI's native collapse toggle from interfering
    event.preventDefault()
    event.stopPropagation()

    const header = event.currentTarget
    // Find the parent step or quantityStep element
    const step = header.closest("[data-variant-selector-target='step'], [data-variant-selector-target='quantityStep']")
    if (!step) return

    const stepIndex = parseInt(step.dataset.stepIndex, 10)

    const isExpanded = step.dataset.expanded === "true"

    if (isExpanded) {
      this.collapseStep(stepIndex)
    } else {
      // Collapse all other steps first
      this.collapseAllSteps()
      this.expandStep(stepIndex)
    }
  }

  /**
   * Handle keyboard events on step headers (Enter/Space to toggle)
   * Required for accessibility when using role="button" on non-button elements
   */
  handleStepKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.toggleStep(event)
    }
  }

  /**
   * Handle keyboard events on tier/quantity cards (Enter/Space to select)
   * Required for accessibility when using role="option" on non-button elements
   */
  handleCardKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      const card = event.currentTarget
      if (card.dataset.tierCard !== undefined) {
        this.selectTier(event)
      } else if (card.dataset.quantityCard !== undefined) {
        this.selectQuantityCard(event)
      }
    }
  }

  /**
   * Select a pricing tier
   * Includes processing guard to prevent race conditions from rapid double-clicks
   */
  selectTier(event) {
    if (this.isProcessing) return

    this.isProcessing = true

    try {
      const tierCard = event.currentTarget
      const quantity = parseInt(tierCard.dataset.quantity, 10)

      this.selectedQuantity = quantity

      // Update tier card selection UI and aria-selected
      this.quantityContentTarget.querySelectorAll("[data-tier-card]").forEach(card => {
        card.classList.remove("border-primary", "border-2")
        card.classList.add("border-gray-200", "border")
        card.setAttribute("aria-selected", "false")
      })
      tierCard.classList.remove("border-gray-200", "border")
      tierCard.classList.add("border-primary", "border-2")
      tierCard.setAttribute("aria-selected", "true")

      // Update quantity step header
      this.updateQuantityStepHeader()

      // Collapse the quantity step
      const quantityStepIndex = this.stepTargets.length
      this.collapseStep(quantityStepIndex)

      // Update totals
      this.updateTotalDisplay()

      // Update form
      this.quantityInputTarget.value = quantity

      // Enable add to cart
      this.enableAddToCart()
    } finally {
      this.isProcessing = false
    }
  }

  /**
   * Add to cart
   */
  addToCart() {
    if (!this.selectedVariant || !this.selectedQuantity) return

    this.variantSkuInputTarget.value = this.selectedVariant.sku
    this.quantityInputTarget.value = this.selectedQuantity
    this.formTarget.requestSubmit()
  }

  // ==================== PRIVATE METHODS ====================

  /**
   * Load selections from URL query params
   * Performs case-insensitive matching since URLs use lowercase values
   */
  loadFromUrlParams() {
    const params = new URLSearchParams(window.location.search)
    const optionKeys = Object.keys(this.optionsValue)

    optionKeys.forEach(key => {
      const urlValue = params.get(key)
      if (urlValue) {
        // Case-insensitive match against actual option values
        const matchedValue = this.optionsValue[key]?.find(
          v => v.toLowerCase() === urlValue.toLowerCase()
        )
        if (matchedValue) {
          this.selections[key] = matchedValue
        }
      }
    })
  }

  /**
   * Update URL with current selections
   * Uses lowercase values for cleaner URLs that are case-insensitive on load
   */
  updateUrl() {
    const params = new URLSearchParams(window.location.search)

    // Set params for each selection (lowercase for cleaner URLs)
    Object.entries(this.selections).forEach(([key, value]) => {
      params.set(key, value.toLowerCase())
    })

    // Update URL without reload
    const newUrl = `${window.location.pathname}?${params.toString()}`
    window.history.replaceState({}, "", newUrl)
  }

  /**
   * Get available values for an option based on UPSTREAM selections only
   * This ensures users can always revise earlier choices without being locked out
   */
  getAvailableValues(optionName) {
    const optionKeys = Object.keys(this.optionsValue)
    const thisOptionIndex = optionKeys.indexOf(optionName)

    // Filter variants that match only UPSTREAM selections (options before this one)
    // This allows all valid choices when revising an earlier step
    const matchingVariants = this.variantsValue.filter(variant => {
      return Object.entries(this.selections).every(([key, value]) => {
        const keyIndex = optionKeys.indexOf(key)
        // Skip this option and all downstream options (options that come after)
        if (keyIndex >= thisOptionIndex) return true
        return variant.option_values[key] === value
      })
    })

    // Get unique values for this option from matching variants
    const values = new Set()
    matchingVariants.forEach(variant => {
      const value = variant.option_values[optionName]
      if (value) values.add(value)
    })

    return values
  }

  /**
   * Update option button enabled/disabled states
   * Uses pill button styling matching the branded configurator
   */
  updateOptionButtons() {
    this.optionButtonTargets.forEach(button => {
      const optionName = button.dataset.optionName
      const value = button.dataset.value

      // Check if this value is available given current selections
      const availableValues = this.getAvailableValues(optionName)
      const isAvailable = availableValues.has(value)
      const isSelected = this.selections[optionName] === value

      // Update button state - pill button styling
      button.disabled = !isAvailable

      // Update aria-pressed for accessibility (toggle button pattern)
      button.setAttribute("aria-pressed", isSelected ? "true" : "false")

      // Selected state: thick green border (matching branded configurator)
      if (isSelected) {
        button.classList.add("border-primary", "border-4")
        button.classList.remove("border-gray-300", "border-2")
      } else {
        button.classList.remove("border-primary", "border-4")
        button.classList.add("border-gray-300", "border-2")
      }

      // Disabled state
      button.classList.toggle("opacity-40", !isAvailable)
      button.classList.toggle("cursor-not-allowed", !isAvailable)
    })
  }

  /**
   * Update step headers to show selections
   * Uses Afida green checkmark indicator with inline selection text
   */
  updateStepHeaders() {
    this.stepTargets.forEach((step, index) => {
      const optionName = step.dataset.optionName
      const selection = this.selections[optionName]
      const indicator = step.querySelector("[data-variant-selector-target='stepIndicator']")
      const selectionDisplay = step.querySelector("[data-variant-selector-target='stepSelection']")

      if (selection) {
        // Show checkmark - Afida green background with white checkmark
        indicator.textContent = "✓"
        indicator.classList.remove("bg-gray-300")
        indicator.classList.add("bg-primary", "text-white")

        // Show selection inline with title (": 7 inch" format)
        if (selectionDisplay) {
          selectionDisplay.textContent = ` : ${selection}`
          selectionDisplay.classList.remove("hidden")
        }
      } else {
        // Show step number - light grey background with white text
        indicator.textContent = String(index + 1)
        indicator.classList.add("bg-gray-300")
        indicator.classList.remove("bg-primary")

        if (selectionDisplay) {
          selectionDisplay.classList.add("hidden")
        }
      }
    })
  }

  /**
   * Update quantity step header
   * Uses Afida green checkmark indicator with inline selection text
   */
  updateQuantityStepHeader() {
    if (!this.hasQuantityStepSelectionTarget) return

    const pacSize = this.selectedVariant?.pac_size || this.pacSizeValue
    const units = this.selectedQuantity * pacSize

    // Show selection inline with title (": 3 packs (1,500 units)" format)
    this.quantityStepSelectionTarget.textContent = ` : ${this.selectedQuantity} pack${this.selectedQuantity > 1 ? "s" : ""} (${units.toLocaleString()} units)`
    this.quantityStepSelectionTarget.classList.remove("hidden")

    // Update indicator to checkmark - Afida green background with white checkmark
    if (this.hasQuantityStepIndicatorTarget) {
      this.quantityStepIndicatorTarget.textContent = "✓"
      this.quantityStepIndicatorTarget.classList.remove("bg-gray-300")
      this.quantityStepIndicatorTarget.classList.add("bg-primary", "text-white")
    }
  }

  /**
   * Clear invalid downstream selections
   */
  clearInvalidDownstreamSelections(changedOptionName) {
    const optionKeys = Object.keys(this.optionsValue)
    const changedIndex = optionKeys.indexOf(changedOptionName)

    // Check each downstream selection
    optionKeys.slice(changedIndex + 1).forEach(key => {
      if (this.selections[key]) {
        const availableValues = this.getAvailableValues(key)
        if (!availableValues.has(this.selections[key])) {
          delete this.selections[key]
        }
      }
    })
  }

  /**
   * Check if all options are selected
   */
  allOptionsSelected() {
    const optionKeys = Object.keys(this.optionsValue)
    return optionKeys.every(key => this.selections[key])
  }

  /**
   * Find variant matching current selections
   */
  findMatchingVariant() {
    if (!this.allOptionsSelected()) {
      this.selectedVariant = null
      return
    }

    this.selectedVariant = this.variantsValue.find(variant => {
      return Object.entries(this.selections).every(([key, value]) => {
        return variant.option_values[key] === value
      })
    })

    // Update SKU display
    if (this.selectedVariant && this.hasSkuDisplayTarget) {
      this.skuDisplayTarget.classList.remove("hidden")
      if (this.hasSkuValueTarget) {
        this.skuValueTarget.textContent = this.selectedVariant.sku
      }
    }

    // Update price display
    if (this.selectedVariant && this.hasPriceDisplayTarget) {
      const price = this.selectedVariant.price
      this.priceDisplayTarget.textContent = `£${price.toFixed(2)} / pack of ${this.selectedVariant.pac_size} units`
    }

    // Update image if variant has one
    if (this.selectedVariant?.image_url && this.hasImageDisplayTarget) {
      this.imageDisplayTarget.src = this.selectedVariant.image_url
    }
  }

  /**
   * Update quantity step content based on selected variant
   */
  updateQuantityStep() {
    if (!this.selectedVariant) return

    const hasTiers = this.selectedVariant.pricing_tiers?.length > 0

    if (hasTiers) {
      this.renderTierCards()
    } else {
      this.renderQuantityButtons()
    }
  }

  /**
   * Clear quantity content with explicit cleanup
   * Stimulus automatically unbinds data-action events when elements are removed,
   * but explicit removal makes intent clear and is more defensive
   */
  clearQuantityContent() {
    const container = this.quantityContentTarget
    while (container.firstChild) {
      container.removeChild(container.firstChild)
    }
  }

  /**
   * Render pricing tier cards using safe DOM methods
   * Uses shared createQuantityCard helper for consistent card structure
   */
  renderTierCards() {
    const tiers = this.selectedVariant.pricing_tiers
    const pacSize = this.selectedVariant.pac_size || this.pacSizeValue
    const basePrice = parseFloat(tiers[0].price)

    // Clear existing content and create container
    this.clearQuantityContent()
    const container = this.createQuantityContainer()

    tiers.forEach((tier, index) => {
      const quantity = tier.quantity
      const price = parseFloat(tier.price)
      const savings = index > 0 ? Math.round((1 - price / basePrice) * 100) : 0

      const card = this.createQuantityCard({
        quantity,
        price,
        pacSize,
        savings,
        isTier: true
      })
      container.appendChild(card)
    })

    this.quantityContentTarget.appendChild(container)
  }

  /**
   * Render quantity buttons using safe DOM methods (fallback for non-tiered products)
   * Uses shared createQuantityCard helper for consistent card structure
   */
  renderQuantityButtons() {
    const pacSize = this.selectedVariant.pac_size || this.pacSizeValue
    const price = this.selectedVariant.price

    // Clear existing content and create container
    this.clearQuantityContent()
    const container = this.createQuantityContainer()

    // Create quantity options (1-5 packs, then 10)
    const quantities = [1, 2, 3, 4, 5, 10]

    quantities.forEach(quantity => {
      const card = this.createQuantityCard({
        quantity,
        price,
        pacSize,
        savings: 0,
        isTier: false
      })
      container.appendChild(card)
    })

    this.quantityContentTarget.appendChild(container)
  }

  /**
   * Create the quantity cards container with accessibility attributes
   */
  createQuantityContainer() {
    const container = document.createElement("div")
    container.className = "space-y-2 pt-4"
    container.setAttribute("role", "listbox")
    container.setAttribute("aria-label", "Select quantity")
    return container
  }

  /**
   * Create a quantity selection card (shared between tier and standard quantity cards)
   * @param {Object} options - Card configuration
   * @param {number} options.quantity - Number of packs
   * @param {number} options.price - Price per pack
   * @param {number} options.pacSize - Units per pack
   * @param {number} options.savings - Savings percentage (0 for no savings)
   * @param {boolean} options.isTier - Whether this is a pricing tier card
   */
  createQuantityCard({ quantity, price, pacSize, savings, isTier }) {
    const units = quantity * pacSize
    const unitPrice = price / pacSize
    const total = price * quantity
    const hasSavings = savings > 0

    // Build accessible label
    let label = `${quantity} pack${quantity > 1 ? "s" : ""}, ${units.toLocaleString()} units, £${total.toFixed(2)} total`
    if (hasSavings) label += `, save ${savings}%`

    // Create card with grid layout (4 columns for tiers with savings, 3 for standard)
    const card = document.createElement("div")
    card.className = "border border-gray-200 bg-white rounded-xl px-4 py-3 cursor-pointer hover:border-primary transition items-center"
    card.style.display = "grid"
    card.style.gridTemplateColumns = isTier ? "1fr auto auto auto" : "1fr auto auto"
    card.style.gap = "0.75rem"

    // Set card type and data attributes
    if (isTier) {
      card.dataset.tierCard = ""
      card.dataset.price = String(price)
      card.dataset.action = "click->variant-selector#selectTier keydown->variant-selector#handleCardKeydown"
    } else {
      card.dataset.quantityCard = ""
      card.dataset.action = "click->variant-selector#selectQuantityCard keydown->variant-selector#handleCardKeydown"
    }
    card.dataset.quantity = String(quantity)
    card.setAttribute("role", "option")
    card.setAttribute("aria-selected", "false")
    card.setAttribute("aria-label", label)
    card.setAttribute("tabindex", "0")

    // Column 1: Quantity with units "1 pack (1,000 units)"
    const quantityDiv = document.createElement("div")
    quantityDiv.className = "text-black whitespace-nowrap"
    quantityDiv.textContent = `${quantity} pack${quantity > 1 ? "s" : ""} (${units.toLocaleString()} units)`
    card.appendChild(quantityDiv)

    // Column 2: Unit price "£0.050/unit"
    const unitPriceDiv = document.createElement("div")
    unitPriceDiv.className = "text-gray-400"
    unitPriceDiv.style.width = "6rem"
    unitPriceDiv.textContent = `£${unitPrice.toFixed(3)}/unit`
    card.appendChild(unitPriceDiv)

    // Column 3 (tier cards only): Savings badge or placeholder
    if (isTier) {
      const badgeContainer = document.createElement("div")
      badgeContainer.style.width = "5rem"
      if (hasSavings) {
        const badge = document.createElement("span")
        badge.className = "bg-green-100 text-green-800 rounded-full px-3 py-1 text-sm"
        badge.textContent = `save ${savings}%`
        badgeContainer.appendChild(badge)
      }
      card.appendChild(badgeContainer)
    }

    // Final column: Total price "£49.82"
    const totalDiv = document.createElement("div")
    totalDiv.className = "text-black text-right"
    totalDiv.style.width = "4.5rem"
    totalDiv.textContent = `£${total.toFixed(2)}`
    card.appendChild(totalDiv)

    return card
  }

  /**
   * Handle quantity card selection (for non-tiered products)
   * Matches branded configurator styling
   * Includes processing guard to prevent race conditions from rapid double-clicks
   */
  selectQuantityCard(event) {
    if (this.isProcessing) return

    this.isProcessing = true

    try {
      const card = event.currentTarget
      const quantity = parseInt(card.dataset.quantity, 10)

      this.selectedQuantity = quantity

      // Update card selection UI and aria-selected
      this.quantityContentTarget.querySelectorAll("[data-quantity-card]").forEach(c => {
        c.classList.remove("border-primary", "border-2")
        c.classList.add("border-gray-200", "border")
        c.setAttribute("aria-selected", "false")
      })
      card.classList.remove("border-gray-200", "border")
      card.classList.add("border-primary", "border-2")
      card.setAttribute("aria-selected", "true")

      // Update quantity step header
      this.updateQuantityStepHeader()

      // Collapse the quantity step
      const quantityStepIndex = this.stepTargets.length
      this.collapseStep(quantityStepIndex)

      // Update totals
      this.updateTotalDisplay()

      // Update form
      this.quantityInputTarget.value = quantity

      // Enable add to cart
      this.enableAddToCart()
    } finally {
      this.isProcessing = false
    }
  }

  /**
   * Update total price displays
   */
  updateTotalDisplay() {
    if (!this.selectedVariant) return

    let price = this.selectedVariant.price

    // Use tier price if available
    if (this.selectedVariant.pricing_tiers?.length > 0) {
      const tier = this.selectedVariant.pricing_tiers.find(t => t.quantity === this.selectedQuantity)
      if (tier) price = parseFloat(tier.price)
    }

    const total = price * this.selectedQuantity
    const formatted = `£${total.toFixed(2)}`

    if (this.hasTotalDisplayTarget) {
      this.totalDisplayTarget.textContent = formatted
    }
    if (this.hasMobileTotalDisplayTarget) {
      this.mobileTotalDisplayTarget.textContent = formatted
    }
  }

  /**
   * Enable add to cart buttons
   */
  enableAddToCart() {
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = false
    }
    if (this.hasMobileAddButtonTarget) {
      this.mobileAddButtonTarget.disabled = false
    }
  }

  /**
   * Disable add to cart buttons
   */
  disableAddToCart() {
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = true
    }
    if (this.hasMobileAddButtonTarget) {
      this.mobileAddButtonTarget.disabled = true
    }
  }

  /**
   * Emit variant changed event for compatible lids integration
   */
  emitVariantChanged() {
    if (!this.selectedVariant) return

    const event = new CustomEvent("variant-selector:variant-changed", {
      bubbles: true,
      detail: {
        variantId: this.selectedVariant.id,
        sku: this.selectedVariant.sku,
        price: this.selectedVariant.price,
        optionValues: this.selectedVariant.option_values
      }
    })
    this.element.dispatchEvent(event)
  }

  // ==================== STEP MANAGEMENT ====================

  /**
   * Get the index of an option step by option name
   */
  getStepIndex(optionName) {
    const optionKeys = Object.keys(this.optionsValue)
    return optionKeys.indexOf(optionName)
  }

  /**
   * Find the first step that doesn't have a selection
   * Returns quantity step index if all options are selected
   */
  getFirstIncompleteStepIndex() {
    const optionKeys = Object.keys(this.optionsValue)
    for (let i = 0; i < optionKeys.length; i++) {
      if (!this.selections[optionKeys[i]]) {
        return i
      }
    }
    // All options have selections, return quantity step index
    return optionKeys.length
  }

  expandStep(index) {
    const allSteps = [...this.stepTargets, this.quantityStepTarget]
    const step = allSteps[index]

    if (!step) return

    step.dataset.expanded = "true"
    // DaisyUI collapse uses collapse-open class to show content
    step.classList.add("collapse-open")

    // Update aria-expanded on the header for accessibility
    const header = step.querySelector("[role='button']")
    if (header) header.setAttribute("aria-expanded", "true")
  }

  collapseStep(index) {
    const allSteps = [...this.stepTargets, this.quantityStepTarget]
    const step = allSteps[index]

    if (!step) return

    step.dataset.expanded = "false"
    // DaisyUI collapse uses collapse-open class to show content
    step.classList.remove("collapse-open")

    // Update aria-expanded on the header for accessibility
    const header = step.querySelector("[role='button']")
    if (header) header.setAttribute("aria-expanded", "false")
  }

  collapseAllSteps() {
    const allSteps = [...this.stepTargets, this.quantityStepTarget]
    allSteps.forEach((step, index) => this.collapseStep(index))
  }
}
