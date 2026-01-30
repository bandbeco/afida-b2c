import { Controller } from "@hotwired/stimulus"

// Handles displaying compatible lids for standard cup products
// Renders as a horizontal mini-carousel with scroll navigation
export default class extends Controller {
  static targets = ["container", "loading", "wrapper"]
  static values = {
    productId: Number
  }

  connect() {
    // Cup quantity is now handled by the variant selector's quantity step
    this.cupQuantity = null
  }

  // Carousel scroll navigation
  scrollLeft() {
    if (this.hasContainerTarget) {
      this.containerTarget.scrollBy({ left: -200, behavior: 'smooth' })
    }
  }

  scrollRight() {
    if (this.hasContainerTarget) {
      this.containerTarget.scrollBy({ left: 200, behavior: 'smooth' })
    }
  }

  // Listen for variant changes from variant-selector controller
  onVariantChanged(event) {
    const size = event.detail.optionValues?.size
    if (size) {
      this.loadCompatibleLids(size)
    }
  }

  updateLidQuantities(cupQuantity) {
    // Find all lid quantity selects and update them
    const quantitySelects = this.containerTarget.querySelectorAll('select[data-lid-quantity]')

    quantitySelects.forEach(select => {
      // Find the option that matches or is closest to the cup quantity
      let bestMatch = null
      let minDiff = Infinity

      Array.from(select.options).forEach(option => {
        const optionValue = parseInt(option.value)
        const diff = Math.abs(optionValue - cupQuantity)

        if (diff < minDiff) {
          minDiff = diff
          bestMatch = option
        }
      })

      if (bestMatch) {
        select.value = bestMatch.value
      }
    })
  }

  async loadCompatibleLids(size) {
    if (!this.productIdValue || !size) return

    // Show loading state
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = 'block'
    }
    this.containerTarget.innerHTML = ''

    try {
      const response = await fetch(`/branded_products/compatible_lids?size=${size}&product_id=${this.productIdValue}`)
      const data = await response.json()

      if (this.hasLoadingTarget) {
        this.loadingTarget.style.display = 'none'
      }

      if (data.lids.length === 0) {
        // No lids available - keep the section hidden
        if (this.hasWrapperTarget) {
          this.wrapperTarget.classList.add('hidden')
        }
        return
      }

      // Show the wrapper section now that we have lids
      if (this.hasWrapperTarget) {
        this.wrapperTarget.classList.remove('hidden')
      }

      // Render lid cards
      data.lids.forEach(lid => {
        this.containerTarget.appendChild(this.createLidCard(lid))
      })

      // Update lid quantities to match current cup quantity if available
      if (this.cupQuantity) {
        this.updateLidQuantities(this.cupQuantity)
      }
    } catch (error) {
      console.error('Failed to load compatible lids:', error)
      if (this.hasLoadingTarget) {
        this.loadingTarget.style.display = 'none'
      }
      // On error, keep section hidden rather than showing error message
      if (this.hasWrapperTarget) {
        this.wrapperTarget.classList.add('hidden')
      }
    }
  }

  createLidCard(lid) {
    // Build landscape card - shows 2 at a time with horizontal layout
    const card = document.createElement('div')
    card.className = 'flex-shrink-0 w-[calc(50%-8px)] bg-white border border-gray-200 rounded-lg p-4 hover:border-primary transition-colors flex gap-4'

    // Image container (left side)
    const imageContainer = document.createElement('div')
    imageContainer.className = 'w-20 h-20 flex-shrink-0'

    if (lid.image_url) {
      const img = document.createElement('img')
      img.src = lid.image_url
      img.alt = lid.name
      img.className = 'w-full h-full object-contain'
      imageContainer.appendChild(img)
    } else {
      const placeholder = document.createElement('div')
      placeholder.className = 'w-full h-full bg-gray-100 flex items-center justify-center rounded text-2xl'
      placeholder.setAttribute('role', 'img')
      placeholder.setAttribute('aria-label', 'Product image placeholder')
      placeholder.textContent = '📦'
      imageContainer.appendChild(placeholder)
    }
    card.appendChild(imageContainer)

    // Content container (right side)
    const content = document.createElement('div')
    content.className = 'flex-1 flex flex-col justify-between min-w-0'

    // Name
    const nameEl = document.createElement('p')
    nameEl.className = 'text-sm font-medium line-clamp-2'
    nameEl.title = lid.name
    nameEl.textContent = lid.name
    content.appendChild(nameEl)

    // Price
    const priceEl = document.createElement('p')
    priceEl.className = 'text-sm text-gray-600'
    priceEl.textContent = `£${parseFloat(lid.price).toFixed(2)} / pack`
    content.appendChild(priceEl)

    // Bottom row: quantity + button stacked on small cards
    const bottomRow = document.createElement('div')
    bottomRow.className = 'flex gap-2 items-center mt-1'

    // Quantity select
    const select = document.createElement('select')
    select.className = 'flex-1 min-w-0 text-xs border border-gray-300 rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-primary bg-white'
    select.setAttribute('data-lid-quantity', lid.sku)

    this.generateLidQuantityOptions(lid.pac_size).forEach(q => {
      const option = document.createElement('option')
      option.value = q.value
      option.textContent = q.label
      select.appendChild(option)
    })
    bottomRow.appendChild(select)

    // Add button with cart + icon
    const button = document.createElement('button')
    button.className = 'btn btn-primary btn-xs btn-square cursor-pointer flex-shrink-0'
    button.setAttribute('data-action', 'click->compatible-lids#addLidToCart')
    button.setAttribute('data-lid-sku', lid.sku)
    button.setAttribute('data-lid-name', lid.name)
    button.setAttribute('aria-label', 'Add to cart')
    button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
    </svg>`
    bottomRow.appendChild(button)

    content.appendChild(bottomRow)
    card.appendChild(content)

    return card
  }

  // Generate quantity options for lid selector
  // Value is number of packs, display shows "X packs (Y units)"
  generateLidQuantityOptions(pac_size) {
    const options = []

    // Add options for 1-10 packs
    for (let numPacks = 1; numPacks <= 10; numPacks++) {
      const totalUnits = pac_size * numPacks
      const packText = numPacks === 1 ? "pack" : "packs"
      options.push({
        value: numPacks,  // Submit number of packs, not units
        label: `${numPacks} ${packText} (${totalUnits.toLocaleString()} units)`
      })
    }

    return options
  }

  // Icon SVGs for button states
  cartIcon = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
  </svg>`

  loadingIcon = `<span class="loading loading-spinner loading-xs"></span>`

  checkIcon = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
  </svg>`

  errorIcon = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
  </svg>`

  async addLidToCart(event) {
    const button = event.currentTarget
    const sku = button.dataset.lidSku
    const quantitySelect = button.parentElement.querySelector('select')
    const quantity = parseInt(quantitySelect.value)

    // Detect button style: icon-only (DaisyUI btn-square) vs text button (full width)
    const isIconButton = button.classList.contains('btn-square')
    const originalText = button.textContent

    // Disable button during request - show loading spinner
    button.disabled = true
    if (isIconButton) {
      // Icon button uses innerHTML for SVG icons (hardcoded, safe)
      button.innerHTML = this.loadingIcon // eslint-disable-line no-unsanitized/property
    } else {
      button.textContent = 'Adding...'
    }

    try {
      const response = await fetch("/cart/cart_items", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken(),
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

        // Show success state
        if (isIconButton) {
          button.innerHTML = this.checkIcon // eslint-disable-line no-unsanitized/property
          button.classList.remove('btn-primary')
          button.classList.add('btn-success')
        } else {
          button.textContent = '✓ Added to Cart'
          button.classList.remove('bg-primary', 'hover:bg-primary-focus')
          button.classList.add('bg-success', 'text-success-content')
        }

        // Open cart drawer (same behavior as main add-to-cart)
        window.dispatchEvent(new CustomEvent('cart:updated', { detail: { source: 'compatible-lids' } }))

        // Reset button after 2 seconds
        setTimeout(() => {
          button.disabled = false
          if (isIconButton) {
            button.innerHTML = this.cartIcon // eslint-disable-line no-unsanitized/property
            button.classList.remove('btn-success')
            button.classList.add('btn-primary')
          } else {
            button.textContent = originalText
            button.classList.remove('bg-success', 'text-success-content')
            button.classList.add('bg-primary', 'hover:bg-primary-focus')
          }
        }, 2000)
      } else {
        throw new Error('Failed to add to cart')
      }
    } catch (error) {
      console.error('Error adding lid to cart:', error)

      if (isIconButton) {
        button.innerHTML = this.errorIcon // eslint-disable-line no-unsanitized/property
        button.classList.remove('btn-primary')
        button.classList.add('btn-error')
      } else {
        button.textContent = '✗ Failed'
        button.classList.remove('bg-primary', 'hover:bg-primary-focus')
        button.classList.add('bg-error', 'text-error-content')
      }

      setTimeout(() => {
        button.disabled = false
        if (isIconButton) {
          button.innerHTML = this.cartIcon // eslint-disable-line no-unsanitized/property
          button.classList.remove('btn-error')
          button.classList.add('btn-primary')
        } else {
          button.textContent = originalText
          button.classList.remove('bg-error', 'text-error-content')
          button.classList.add('bg-primary', 'hover:bg-primary-focus')
        }
      }, 2000)
    }
  }

  getCSRFToken() {
    const meta = document.querySelector("[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
