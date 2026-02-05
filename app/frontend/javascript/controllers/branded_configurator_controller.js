import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sizeOption",
    "quantityOption",
    "quantityLabel",
    "pricePerUnit",
    "savingsBadge",
    "totalPrice",
    "subtotal",
    "vat",
    "total",
    "addToCartButton",
    "designInput",
    "designPreview",
    "errorMessage",
    "sizeIndicator",
    "quantityIndicator",
    "lidsIndicator",
    "designIndicator",
    "sizeStep",
    "quantityStep",
    "lidsStep",
    "designStep",
    "lidsContainer",
    "sizeSelection",
    "quantitySelection",
    "lidsSelection",
    "designSelection"
  ]

  static values = {
    productId: Number,
    inModal: { type: Boolean, default: false }
  }

  connect() {
    this.selectedSize = null
    this.selectedQuantity = null
    this.calculatedPrice = null
    this.isProcessing = false
    this.updateAddToCartButton()

    // Check for URL parameters and pre-select configuration
    this.loadFromUrlParams()
  }

  getCSRFToken() {
    const meta = document.querySelector("[name='csrf-token']")
    return meta ? meta.content : ""
  }

  loadFromUrlParams() {
    const params = new URLSearchParams(window.location.search)

    // Pre-select size if in URL (normalize: "8 oz" or "8oz" → "8oz")
    const sizeParam = params.get('size')
    if (sizeParam) {
      const normalizedSize = sizeParam.replace(/\s+/g, '')
      const sizeButton = this.sizeOptionTargets.find(el =>
        el.dataset.size.replace(/\s+/g, '') === normalizedSize
      )
      if (sizeButton) {
        sizeButton.click()
      }
    }

    // Pre-select quantity if in URL
    const quantityParam = params.get('quantity')
    if (quantityParam) {
      const quantity = parseInt(quantityParam)
      const quantityCard = this.quantityOptionTargets.find(el =>
        parseInt(el.dataset.quantity) === quantity
      )
      if (quantityCard) {
        quantityCard.click()
      }
    }
  }

  // ==================== STEP MANAGEMENT ====================

  /**
   * Toggle step expansion when clicking header
   */
  toggleStep(event) {
    // Prevent any default behavior
    event.preventDefault()
    event.stopPropagation()

    const header = event.currentTarget
    const step = header.closest("[data-step-index]")
    if (!step) return

    const stepIndex = parseInt(step.dataset.stepIndex, 10)
    const isExpanded = step.dataset.expanded === "true"

    if (isExpanded) {
      this.collapseStep(step)
    } else {
      // Collapse all steps first
      this.collapseAllSteps()
      this.expandStep(step)
    }
  }

  /**
   * Handle keyboard events on step headers (Enter/Space to toggle)
   */
  handleStepKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.toggleStep(event)
    }
  }

  /**
   * Handle keyboard events on quantity cards (Enter/Space to select)
   */
  handleCardKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.selectQuantity(event)
    }
  }

  expandStep(step) {
    step.dataset.expanded = "true"
    step.classList.add("collapse-open")

    const header = step.querySelector("[role='button']")
    if (header) header.setAttribute("aria-expanded", "true")
  }

  collapseStep(step) {
    step.dataset.expanded = "false"
    step.classList.remove("collapse-open")

    const header = step.querySelector("[role='button']")
    if (header) header.setAttribute("aria-expanded", "false")
  }

  collapseAllSteps() {
    const allSteps = [
      this.sizeStepTarget,
      this.quantityStepTarget,
      this.lidsStepTarget,
      this.designStepTarget
    ].filter(Boolean)

    allSteps.forEach(step => this.collapseStep(step))
  }

  getStepByName(stepName) {
    const targetName = `${stepName}StepTarget`
    return this[targetName] || null
  }

  selectSize(event) {
    if (this.isProcessing) return
    this.isProcessing = true

    try {
      // Reset all size buttons to unselected state
      this.sizeOptionTargets.forEach(el => {
        el.classList.remove("border-primary", "border-4")
        el.classList.add("border-gray-300", "border-2")
        el.setAttribute("aria-pressed", "false")
      })

      // Add selected state to clicked button
      event.currentTarget.classList.remove("border-gray-300", "border-2")
      event.currentTarget.classList.add("border-primary", "border-4")
      event.currentTarget.setAttribute("aria-pressed", "true")

      this.selectedSize = event.currentTarget.dataset.size
      this.updateUrl()
      this.showStepComplete('size')
      this.updateSelectionDisplay('size', this.selectedSize)

      // Collapse current step and expand next
      this.collapseStep(this.sizeStepTarget)
      this.expandStep(this.quantityStepTarget)

      this.calculatePrice()
    } finally {
      this.isProcessing = false
    }
  }

  selectQuantity(event) {
    if (this.isProcessing) return
    this.isProcessing = true

    try {
      // Reset all quantity cards to unselected state
      this.quantityOptionTargets.forEach(el => {
        el.classList.remove("border-primary", "border-2")
        el.classList.add("border-gray-200", "border")
        el.setAttribute("aria-selected", "false")
      })

      // Add selected state to clicked card
      event.currentTarget.classList.remove("border-gray-200", "border")
      event.currentTarget.classList.add("border-primary", "border-2")
      event.currentTarget.setAttribute("aria-selected", "true")

      this.selectedQuantity = parseInt(event.currentTarget.dataset.quantity)
      this.updateUrl()
      this.showStepComplete('quantity')
      this.updateSelectionDisplay('quantity', this.selectedQuantity.toLocaleString() + ' units')

      // Collapse quantity step and expand lids step (or design in modal mode)
      this.collapseStep(this.quantityStepTarget)
      if (this.inModalValue) {
        this.expandStep(this.designStepTarget)
      } else {
        this.expandStep(this.lidsStepTarget)
        this.loadCompatibleLids()
      }

      this.calculatePrice()
    } finally {
      this.isProcessing = false
    }
  }

  async loadCompatibleLids() {
    if (!this.selectedSize) return

    // Show loading state
    document.getElementById('lids-loading').style.display = 'block'
    while (this.lidsContainerTarget.firstChild) {
      this.lidsContainerTarget.removeChild(this.lidsContainerTarget.firstChild)
    }

    try {
      // Pass product_id to match lid type (not just size)
      const response = await fetch(`/branded_products/compatible_lids?size=${this.selectedSize}&product_id=${this.productIdValue}`)
      const data = await response.json()

      document.getElementById('lids-loading').style.display = 'none'

      if (data.lids.length === 0) {
        this.showLidsMessage('No compatible lids available for this size', 'text-gray-500')
        return
      }

      // Render lid cards
      data.lids.forEach(lid => {
        this.lidsContainerTarget.appendChild(this.createLidCard(lid))
      })
    } catch (error) {
      console.error('Failed to load compatible lids:', error)
      document.getElementById('lids-loading').style.display = 'none'
      this.showLidsMessage('Failed to load lids. Please try again.', 'text-error')
    }
  }

  showLidsMessage(message, colorClass) {
    while (this.lidsContainerTarget.firstChild) {
      this.lidsContainerTarget.removeChild(this.lidsContainerTarget.firstChild)
    }
    const p = document.createElement('p')
    p.className = `${colorClass} col-span-full text-center py-8`
    p.textContent = message
    this.lidsContainerTarget.appendChild(p)
  }

  createLidCard(lid) {
    const card = document.createElement('div')
    card.className = 'bg-white border-2 border-gray-200 rounded-lg hover:border-primary transition-colors p-3 sm:p-4'

    const wrapper = document.createElement('div')
    wrapper.className = 'flex items-start gap-3 sm:gap-4'

    // Image container
    const imageContainer = document.createElement('div')
    imageContainer.className = 'flex-shrink-0 w-20 h-20 sm:w-24 sm:h-24'

    if (lid.image_url) {
      const img = document.createElement('img')
      img.src = lid.image_url
      img.alt = lid.name
      img.className = 'w-full h-full object-contain'
      imageContainer.appendChild(img)
    } else {
      const placeholder = document.createElement('div')
      placeholder.className = 'w-full h-full bg-gray-100 flex items-center justify-center rounded text-3xl sm:text-4xl'
      placeholder.setAttribute('role', 'img')
      placeholder.setAttribute('aria-label', 'Product image placeholder')
      placeholder.textContent = '📦'
      imageContainer.appendChild(placeholder)
    }

    // Content container
    const content = document.createElement('div')
    content.className = 'flex-1 min-w-0'

    // Material and size as the main identifier
    const title = document.createElement('h3')
    title.className = 'text-base sm:text-lg mb-1 leading-tight'
    const titleParts = []
    if (lid.material) titleParts.push(lid.material)
    if (lid.size) titleParts.push(lid.size)
    title.textContent = titleParts.length > 0 ? `${titleParts.join(' · ')} compatible` : lid.name

    const price = document.createElement('div')
    price.className = 'text-sm sm:text-base text-gray-900'
    price.textContent = `£${parseFloat(lid.price).toFixed(2)} / pack of ${lid.pac_size.toLocaleString()}`

    // Actions - stacked vertically
    const actions = document.createElement('div')
    actions.className = 'flex flex-col gap-2 mt-3'

    const select = document.createElement('select')
    select.className = 'w-full px-2 sm:px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent bg-white'
    select.dataset.lidQuantity = lid.sku

    this.generateLidQuantityOptions(lid.pac_size, this.selectedQuantity).forEach(q => {
      const option = document.createElement('option')
      option.value = q.value
      option.textContent = q.label
      if (q.selected) option.selected = true
      select.appendChild(option)
    })

    const button = document.createElement('button')
    button.className = 'w-full px-3 sm:px-4 py-2 text-sm font-medium text-black bg-primary hover:bg-primary-focus rounded-md transition-colors cursor-pointer'
    button.dataset.action = 'click->branded-configurator#addLidToCart'
    button.dataset.lidSku = lid.sku
    button.dataset.lidName = lid.name
    button.textContent = 'Add to Cart'

    actions.appendChild(select)
    actions.appendChild(button)

    content.appendChild(title)
    content.appendChild(price)
    content.appendChild(actions)

    wrapper.appendChild(imageContainer)
    wrapper.appendChild(content)
    card.appendChild(wrapper)

    return card
  }

  // Generate quantity options for lid selector
  // Value is number of packs, display shows "X packs (Y units)"
  // cupQuantity is in units (for branded products), so we convert to packs for auto-selection
  generateLidQuantityOptions(pac_size, cupQuantity) {
    const options = []

    // Calculate how many packs would match the cup quantity
    const matchingPacks = cupQuantity ? Math.ceil(cupQuantity / pac_size) : null

    // Add options for 1-10 packs
    for (let numPacks = 1; numPacks <= 10; numPacks++) {
      const totalUnits = pac_size * numPacks
      const packText = numPacks === 1 ? "pack" : "packs"
      options.push({
        value: numPacks,  // Submit number of packs, not units
        label: `${numPacks} ${packText} (${totalUnits.toLocaleString()} units)`,
        selected: numPacks === matchingPacks
      })
    }

    return options
  }

  async calculatePrice() {
    if (!this.selectedSize) {
      return
    }

    // Update all quantity cards with pricing for the selected size
    await this.updateAllQuantityPricing()

    // If a quantity is selected, update the summary
    if (this.selectedQuantity) {
      await this.updateSelectedQuantityPricing()
    }

    this.updateAddToCartButton()
  }

  async updateAllQuantityPricing() {
    // Get pricing for all quantity tiers
    const promises = this.quantityOptionTargets.map(async (card) => {
      const quantity = parseInt(card.dataset.quantity)

      try {
        const response = await fetch("/branded_products/calculate_price", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
          },
          body: JSON.stringify({
            product_id: this.productIdValue,
            size: this.selectedSize,
            quantity: quantity
          })
        })

        const data = await response.json()

        if (data.success) {
          // Find the targets within this card
          const priceTarget = card.querySelector('[data-branded-configurator-target="pricePerUnit"]')
          const totalTarget = card.querySelector('[data-branded-configurator-target="totalPrice"]')

          if (priceTarget) {
            priceTarget.textContent = `£${parseFloat(data.price_per_unit).toFixed(3)}/unit`
          }
          if (totalTarget) {
            totalTarget.textContent = `£${parseFloat(data.total_price).toFixed(2)}`
          }

          // Store price per unit for savings calculation
          card.dataset.pricePerUnit = data.price_per_unit
        }
      } catch (error) {
        console.error("Failed to calculate price for quantity:", quantity, error)
      }
    })

    await Promise.all(promises)

    // Calculate and display savings relative to first tier
    if (this.quantityOptionTargets.length > 1) {
      const basePrice = parseFloat(this.quantityOptionTargets[0].dataset.pricePerUnit)

      this.quantityOptionTargets.forEach((card, index) => {
        if (index > 0 && card.dataset.pricePerUnit) {
          const cardPrice = parseFloat(card.dataset.pricePerUnit)
          const savingsPercent = Math.round(((basePrice - cardPrice) / basePrice) * 100)
          const savingsTarget = card.querySelector('[data-branded-configurator-target="savingsBadge"]')

          if (savingsTarget && savingsPercent > 0) {
            savingsTarget.textContent = `save ${savingsPercent}%`
            savingsTarget.classList.remove('invisible')
            savingsTarget.classList.add('text-success', 'text-sm', 'font-medium')
          }
        }
      })
    }
  }

  async updateSelectedQuantityPricing() {
    try {
      const response = await fetch("/branded_products/calculate_price", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: JSON.stringify({
          product_id: this.productIdValue,
          size: this.selectedSize,
          quantity: this.selectedQuantity
        })
      })

      const data = await response.json()

      if (data.success) {
        this.calculatedPrice = data.total_price
        this.updateSummaryDisplay(data)
        this.clearError()
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError("Failed to calculate price. Please try again.")
    }
  }

  updateSummaryDisplay(data) {
    // Parse values as floats (server returns strings)
    // All prices displayed excl. VAT
    const subtotal = parseFloat(data.total_price)

    // Update subtotal (if target exists)
    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = `£${subtotal.toFixed(2)}`
    }

    // Update total (excl. VAT)
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = `£${subtotal.toFixed(2)}`
    }
  }

  handleDesignUpload(event) {
    const file = event.target.files[0]
    if (!file) return

    // Validate file type
    const validTypes = ["application/pdf", "image/png", "image/jpeg", "application/postscript"]
    if (!validTypes.includes(file.type)) {
      this.showError("Please upload a PDF, PNG, JPG, or AI file")
      event.target.value = ""
      return
    }

    // Validate file size (max 10MB)
    const maxSize = 10 * 1024 * 1024
    if (file.size > maxSize) {
      this.showError("File size must be less than 10MB")
      event.target.value = ""
      return
    }

    // Show preview
    if (this.hasDesignPreviewTarget) {
      this.designPreviewTarget.textContent = file.name
      this.designPreviewTarget.classList.remove("hidden")
    }

    this.clearError()
    this.showStepComplete('design')
    this.updateSelectionDisplay('design', file.name)

    // Collapse design step after upload
    this.collapseStep(this.designStepTarget)

    this.updateAddToCartButton()
  }

  updateUrl() {
    const params = new URLSearchParams(window.location.search)

    // Update URL parameters based on current selections
    if (this.selectedSize) {
      params.set('size', this.selectedSize)
    }
    if (this.selectedQuantity) {
      params.set('quantity', this.selectedQuantity)
    }

    // Update browser URL without page reload
    const newUrl = `${window.location.pathname}?${params.toString()}`
    window.history.replaceState({}, '', newUrl)
  }

  showStepComplete(step) {
    const indicatorTarget = `${step}IndicatorTarget`
    if (this[indicatorTarget]) {
      // Transform to checkmark - Afida green background with white checkmark
      this[indicatorTarget].textContent = '✓'
      this[indicatorTarget].classList.remove('bg-gray-300')
      this[indicatorTarget].classList.add('bg-primary', 'text-white')
    }
  }

  skipLids(event) {
    // Mark step complete and move to design
    this.showStepComplete('lids')
    this.updateSelectionDisplay('lids', 'skipped')

    // Collapse lids step and expand design step
    this.collapseStep(this.lidsStepTarget)
    this.expandStep(this.designStepTarget)
  }

  /**
   * Update selection display with colon format to match variant selector
   * Shows ": value" inline with the step title
   */
  updateSelectionDisplay(step, value) {
    const selectionTarget = `${step}SelectionTarget`
    if (this[`has${step.charAt(0).toUpperCase() + step.slice(1)}SelectionTarget`] && this[selectionTarget]) {
      this[selectionTarget].textContent = ` : ${value}`
      this[selectionTarget].classList.remove('hidden')
    }
  }

  async addLidToCart(event) {
    const button = event.currentTarget
    const sku = button.dataset.lidSku
    const name = button.dataset.lidName
    const quantitySelect = button.parentElement.querySelector('select')
    const quantity = parseInt(quantitySelect.value)

    // Disable button during request
    button.disabled = true
    button.textContent = 'Adding...'

    try {
      const response = await fetch("/cart/cart_items", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          cart_item: {
            sku: sku,
            quantity: quantity
          }
        })
      })

      if (response.ok) {
        // Process turbo stream to update cart counter
        const text = await response.text()
        if (text) {
          Turbo.renderStreamMessage(text)
        }

        // Show success feedback
        button.textContent = '✓ Added to cart'
        button.classList.remove('bg-primary', 'hover:bg-primary-focus')
        button.classList.add('bg-success', 'hover:bg-success')

        // Update step indicator and selection display
        this.showStepComplete('lids')
        this.updateSelectionDisplay('lids', 'added')

        // Collapse lids step and expand design step
        this.collapseStep(this.lidsStepTarget)
        this.expandStep(this.designStepTarget)

        // Reset after 2 seconds
        setTimeout(() => {
          button.textContent = 'Add to cart'
          button.classList.remove('bg-success', 'hover:bg-success')
          button.classList.add('bg-primary', 'hover:bg-primary-focus')
          button.disabled = false
        }, 2000)
      } else {
        throw new Error('Failed to add lid')
      }
    } catch (error) {
      this.showError(`Failed to add ${name}`)
      button.disabled = false
      button.textContent = 'Add to cart'
    }
  }

  updateAddToCartButton() {
    if (!this.hasAddToCartButtonTarget) return

    const isValid = this.selectedSize &&
                    this.selectedQuantity &&
                    this.calculatedPrice &&
                    this.designInputTarget?.files.length > 0

    this.addToCartButtonTarget.disabled = !isValid

    if (isValid) {
      this.addToCartButtonTarget.classList.remove("btn-disabled")
    } else {
      this.addToCartButtonTarget.classList.add("btn-disabled")
    }
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  async addToCart(event) {
    event.preventDefault()

    if (!this.selectedSize) {
      this.showError("Please select a size")
      return
    }

    if (!this.selectedQuantity) {
      this.showError("Please select a quantity")
      return
    }

    if (!this.designInputTarget?.files[0]) {
      this.showError("Please upload your design file")
      return
    }

    if (!this.calculatedPrice) {
      this.showError("Price calculation failed. Please try again")
      return
    }

    const formData = new FormData()
    formData.append("product_id", this.productIdValue)
    formData.append("configuration[size]", this.selectedSize)
    formData.append("configuration[quantity]", this.selectedQuantity)
    formData.append("calculated_price", this.calculatedPrice)

    if (this.designInputTarget.files[0]) {
      formData.append("design", this.designInputTarget.files[0])
    }

    try {
      const response = await fetch("/cart/cart_items", {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.getCSRFToken(),
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: formData
      })

      if (response.ok) {
        // Turbo Stream will update the cart counter
        const text = await response.text()
        if (text) {
          Turbo.renderStreamMessage(text)

          if (this.inModalValue) {
            // In modal: dispatch event to close modal
            window.dispatchEvent(new CustomEvent('addon:added'))
          }
          // Product added to cart - cart counter updated via Turbo Stream

          // Reset the configurator form
          this.resetConfigurator()
        }
      } else {
        const data = await response.json()
        this.showError(data.error || "Failed to add to cart")
      }
    } catch (error) {
      this.showError("Failed to add to cart. Please try again.")
    }
  }

  resetConfigurator() {
    // Reset state variables
    this.selectedSize = null
    this.selectedQuantity = null
    this.calculatedPrice = null

    // Reset size buttons
    this.sizeOptionTargets.forEach(el => {
      el.classList.remove("border-primary", "border-4")
      el.classList.add("border-gray-300", "border-2")
      el.setAttribute("aria-pressed", "false")
    })

    // Reset quantity cards
    this.quantityOptionTargets.forEach(el => {
      el.classList.remove("border-primary", "border-2")
      el.classList.add("border-gray-200", "border")
      el.setAttribute("aria-selected", "false")
    })

    // Reset design file input
    if (this.hasDesignInputTarget) {
      this.designInputTarget.value = ""
    }

    // Hide design preview
    if (this.hasDesignPreviewTarget) {
      this.designPreviewTarget.classList.add("hidden")
    }

    // Reset step indicators and selection displays
    const steps = ['size', 'quantity', 'lids', 'design']
    steps.forEach((step, index) => {
      const indicatorTarget = `${step}IndicatorTarget`
      if (this[indicatorTarget]) {
        this[indicatorTarget].textContent = (index + 1).toString()
        this[indicatorTarget].classList.remove('bg-primary', 'text-white')
        this[indicatorTarget].classList.add('bg-gray-300')
      }

      const selectionTarget = `${step}SelectionTarget`
      const hasMethod = `has${step.charAt(0).toUpperCase() + step.slice(1)}SelectionTarget`
      if (this[hasMethod] && this[selectionTarget]) {
        this[selectionTarget].textContent = ''
        this[selectionTarget].classList.add('hidden')
      }
    })

    // Reset pricing display
    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = '£0.00'
    }
    if (this.hasVatTarget) {
      this.vatTarget.textContent = '£0.00'
    }
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = '£0.00'
    }

    // Clear lids container using safe DOM method (if not in modal)
    if (!this.inModalValue && this.hasLidsContainerTarget) {
      while (this.lidsContainerTarget.firstChild) {
        this.lidsContainerTarget.removeChild(this.lidsContainerTarget.firstChild)
      }
    }

    // Collapse all steps and open the first one (size)
    this.collapseAllSteps()
    if (this.hasSizeStepTarget) {
      this.expandStep(this.sizeStepTarget)
    }

    // Update add to cart button state
    this.updateAddToCartButton()

    // Clear any error messages
    this.clearError()

    // Clear URL parameters
    window.history.replaceState({}, '', window.location.pathname)
  }
}
