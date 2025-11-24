import { Controller } from "@hotwired/stimulus"

// Handles displaying compatible lids for standard cup products
export default class extends Controller {
  static targets = ["container", "loading"]
  static values = {
    productId: Number
  }

  connect() {
    // Get initial cup quantity from the product quantity select if it exists
    const quantitySelect = document.querySelector('[data-product-options-target="quantitySelect"]')
    this.cupQuantity = quantitySelect ? parseInt(quantitySelect.value) : null
  }

  // Listen for variant changes from product-options controller
  onVariantChanged(event) {
    const size = event.detail.size
    if (size) {
      this.loadCompatibleLids(size)
    }
  }

  // Listen for quantity changes from product-options controller
  onQuantityChanged(event) {
    const quantity = event.detail.quantity
    this.cupQuantity = quantity

    // Update all lid quantity selects to match cup quantity
    this.updateLidQuantities(quantity)
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
        this.containerTarget.innerHTML = '<p class="text-base-content/60 text-center py-4">No compatible lids available for this size</p>'
        return
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
      this.containerTarget.innerHTML = '<p class="text-error text-center py-4">Failed to load lids. Please try again.</p>'
    }
  }

  createLidCard(lid) {
    const card = document.createElement('div')
    card.className = 'bg-white border-2 border-gray-200 rounded-lg hover:border-primary transition-colors'

    card.innerHTML = `
      <div class="flex items-center gap-4 p-3">
        <!-- Image -->
        <div class="flex-shrink-0 w-20 h-20">
          ${lid.image_url ?
            `<img src="${lid.image_url}" alt="${lid.name}" class="w-full h-full object-contain" />` :
            '<div class="w-full h-full bg-gray-100 flex items-center justify-center rounded text-3xl">📦</div>'
          }
        </div>

        <!-- Content -->
        <div class="flex-1 min-w-0">
          <h4 class="font-semibold text-base mb-1">${lid.name}</h4>
          <div class="text-base text-gray-900">£${parseFloat(lid.price).toFixed(2)}</div>
          <div class="text-sm text-gray-500 mt-1">Pack of ${lid.pac_size.toLocaleString()}</div>
        </div>

        <!-- Actions -->
        <div class="flex-shrink-0 flex flex-col gap-2" style="min-width: 160px;">
          <select class="px-3 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent bg-white w-full" data-lid-quantity="${lid.sku}">
            ${this.generateLidQuantityOptions(lid.pac_size).map(q =>
              `<option value="${q.value}">${q.label}</option>`
            ).join('')}
          </select>
          <button class="px-4 py-2 text-sm font-medium text-black bg-primary hover:bg-primary-focus rounded-md transition-colors whitespace-nowrap w-full cursor-pointer"
                  data-action="click->compatible-lids#addLidToCart"
                  data-lid-sku="${lid.sku}"
                  data-lid-name="${lid.name}">
            Add to cart
          </button>
        </div>
      </div>
    `
    return card
  }

  generateLidQuantityOptions(pac_size) {
    const MAX_QUANTITY = 30000
    const options = []

    // Add pack multiples up to 10,000 units
    for (let i = 1; i <= 10; i++) {
      const quantity = pac_size * i
      if (quantity > 10000) break
      const numPacks = i
      options.push({
        value: quantity,
        label: `${quantity.toLocaleString()} units (${numPacks} ${numPacks === 1 ? 'pack' : 'packs'})`
      })
    }

    // Add 5,000-unit increments from 15,000 to 30,000
    for (let quantity = 15000; quantity <= MAX_QUANTITY; quantity += 5000) {
      const numPacks = Math.ceil(quantity / pac_size)
      options.push({
        value: quantity,
        label: `${quantity.toLocaleString()} units (${numPacks} ${numPacks === 1 ? 'pack' : 'packs'})`
      })
    }

    return options
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
          "X-CSRF-Token": this.getCSRFToken(),
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          cart_item: {
            variant_sku: sku,
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
        button.textContent = 'Added ✓'
        button.classList.remove('bg-primary', 'hover:bg-primary-focus')
        button.classList.add('bg-success')

        // Reset button after 2 seconds
        setTimeout(() => {
          button.disabled = false
          button.textContent = 'Add to cart'
          button.classList.remove('bg-success')
          button.classList.add('bg-primary', 'hover:bg-primary-focus')
        }, 2000)
      } else {
        throw new Error('Failed to add to cart')
      }
    } catch (error) {
      console.error('Error adding lid to cart:', error)
      button.textContent = 'Error - Try again'
      button.classList.add('bg-error')

      setTimeout(() => {
        button.disabled = false
        button.textContent = 'Add to cart'
        button.classList.remove('bg-error')
      }, 2000)
    }
  }

  getCSRFToken() {
    const meta = document.querySelector("[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
