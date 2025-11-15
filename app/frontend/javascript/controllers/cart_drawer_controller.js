import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log('Cart drawer controller connected')

    // Listen for cart:updated event from quick add modal
    window.addEventListener('cart:updated', this.handleCartUpdated.bind(this))
  }

  disconnect() {
    window.removeEventListener('cart:updated', this.handleCartUpdated.bind(this))
  }

  handleCartUpdated(event) {
    console.log('Cart updated event received', event.detail)
    this.openDrawer()
  }

  open(event) {
    if (event.detail.success) {
      console.log('Opening cart drawer')
      this.openDrawer()
    }
  }

  close(event) {
    if (event.detail.success) {
      console.log('Closing cart drawer')
      const drawer = document.querySelector('#cart-drawer')
      if (drawer) {
        console.log('Drawer found, setting checked to false')
        drawer.checked = false
      }
    }
  }

  openDrawer() {
    const drawer = document.querySelector('#cart-drawer')
    if (drawer) {
      console.log('Drawer found, setting checked to true')
      drawer.checked = true
    }
  }
} 