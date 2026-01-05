// Vite + Rails entrypoint with optimized lazy loading

// Polyfills for beautiful confirm dialogs (broader browser support)
import "invokers-polyfill"
import "dialog-closedby-polyfill"

import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// Start Stimulus application
const application = Application.start()

// CORE CONTROLLERS - Always loaded (used on most pages)
import FormController from "../javascript/controllers/form_controller"
application.register("form", FormController)

import SearchController from "../javascript/controllers/search_controller"
application.register("search", SearchController)

import CartDrawerController from "../javascript/controllers/cart_drawer_controller"
application.register("cart-drawer", CartDrawerController)

import AutoDismissController from "../javascript/controllers/auto_dismiss_controller"
application.register("auto-dismiss", AutoDismissController)

import ClickableCardController from "../javascript/controllers/clickable_card_controller"
application.register("clickable-card", ClickableCardController)

// LAZY LOADED CONTROLLERS - Only loaded when needed
const lazyControllers = {
  "analytics": () => import("../javascript/controllers/analytics_controller"),
  "carousel": () => import("../javascript/controllers/carousel_controller"),
  "branded-configurator": () => import("../javascript/controllers/branded_configurator_controller"),
  "product-card-hover": () => import("../javascript/controllers/product_card_hover_controller"),
  "product-options": () => import("../javascript/controllers/product_options_controller"),
  "variant-selector": () => import("../javascript/controllers/variant_selector_controller"),
  "compatible-lids": () => import("../javascript/controllers/compatible_lids_controller"),
  "faq-search": () => import("../javascript/controllers/faq_search_controller"),
  "addon": () => import("../javascript/controllers/addon_controller"),
  "nested-form": () => import("../javascript/controllers/nested_form_controller"),
  "redirect-form": () => import("../javascript/controllers/redirect_form_controller"),
  "character-counter": () => import("../javascript/controllers/character_counter_controller"),
  "quick-add-modal": () => import("../javascript/controllers/quick_add_modal_controller"),
  "quick-add-form": () => import("../javascript/controllers/quick_add_form_controller"),
  "slide-in": () => import("../javascript/controllers/slide_in_controller"),
  "category-expand": () => import("../javascript/controllers/category_expand_controller"),
  "sample-counter": () => import("../javascript/controllers/sample_counter_controller"),
  "related-products": () => import("../javascript/controllers/related_products_controller"),
  "product-configurator": () => import("../javascript/controllers/product_configurator_controller"),
  "account-dropdown": () => import("../javascript/controllers/account_dropdown_controller"),
  "password-visibility": () => import("../javascript/controllers/password_visibility_controller"),
  "save-address-prompt": () => import("../javascript/controllers/save_address_prompt_controller")
}

// Lazy load controllers when their elements appear in DOM
const loadedControllers = new Set()

function lazyLoadController(name) {
  if (loadedControllers.has(name) || !lazyControllers[name]) return

  loadedControllers.add(name)
  lazyControllers[name]().then(module => {
    application.register(name, module.default)
  })
}

// Check for controllers on page load and after Turbo navigation
function checkForLazyControllers() {
  Object.keys(lazyControllers).forEach(name => {
    if (document.querySelector(`[data-controller~="${name}"]`)) {
      lazyLoadController(name)
    }
  })
}

// Initial check
checkForLazyControllers()

// Check after Turbo navigations
document.addEventListener("turbo:load", checkForLazyControllers)
document.addEventListener("turbo:frame-load", checkForLazyControllers)

// Configure Stimulus
application.debug = false
window.Stimulus = application

// Lazy load ActiveStorage only on pages that need it (file uploads)
if (document.querySelector('[data-direct-upload-url]')) {
  import('@rails/activestorage').then(ActiveStorage => {
    ActiveStorage.start()
  })
}

// Beautiful confirm dialogs (modern browsers)
// Falls back to native confirm() for older browsers
import { Turbo } from "@hotwired/turbo-rails"

function setupTurboConfirm() {
  const dialog = document.getElementById("turbo-confirm-dialog")
  if (!dialog) return

  const messageEl = document.getElementById("confirm-dialog-message")
  const confirmBtn = dialog.querySelector('button[value="confirm"]')

  Turbo.config.forms.confirm = (message, element, submitter) => {
    // Feature detection - fallback to native for older browsers
    if (!dialog.showModal) return Promise.resolve(confirm(message))

    messageEl.textContent = message

    // Allow custom button text via data-turbo-confirm-button
    const buttonText = submitter?.dataset.turboConfirmButton || "Confirm"
    confirmBtn.textContent = buttonText

    // Destructive styling based on action
    const isDestructive = submitter?.dataset.turboConfirmDestructive !== "false"
    confirmBtn.className = isDestructive ? "btn btn-error" : "btn btn-primary"

    dialog.showModal()

    return new Promise((resolve) => {
      dialog.addEventListener("close", () => {
        resolve(dialog.returnValue === "confirm")
      }, { once: true })
    })
  }
}

document.addEventListener("turbo:load", setupTurboConfirm)
document.addEventListener("DOMContentLoaded", setupTurboConfirm)
