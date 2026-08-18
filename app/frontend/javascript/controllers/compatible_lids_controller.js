import { Controller } from "@hotwired/stimulus"

// Add-to-cart behaviour for the server-rendered compatible-lids cards on
// product pages, plus scroll navigation for the card container.
export default class extends Controller {
  static targets = ["container"]

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
