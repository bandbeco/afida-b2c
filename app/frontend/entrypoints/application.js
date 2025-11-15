// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails')

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// Start Stimulus application
const application = Application.start()

// Import all controllers
import CartDrawerController from "../javascript/controllers/cart_drawer_controller"
application.register("cart-drawer", CartDrawerController)

import CarouselController from "../javascript/controllers/carousel_controller"
application.register("carousel", CarouselController)

import BrandedConfiguratorController from "../javascript/controllers/branded_configurator_controller"
application.register("branded-configurator", BrandedConfiguratorController)

import ProductCardHoverController from "../javascript/controllers/product_card_hover_controller"
application.register("product-card-hover", ProductCardHoverController)

import ProductOptionsController from "../javascript/controllers/product_options_controller"
application.register("product-options", ProductOptionsController)

import CompatibleLidsController from "../javascript/controllers/compatible_lids_controller"
application.register("compatible-lids", CompatibleLidsController)

import FaqSearchController from "../javascript/controllers/faq_search_controller"
application.register("faq-search", FaqSearchController)

import AddonController from "../javascript/controllers/addon_controller"
application.register("addon", AddonController)

import NestedFormController from "../javascript/controllers/nested_form_controller"
application.register("nested-form", NestedFormController)

import RedirectFormController from "../javascript/controllers/redirect_form_controller"
application.register("redirect-form", RedirectFormController)

import FormController from "../javascript/controllers/form_controller"
application.register("form", FormController)

import SearchController from "../javascript/controllers/search_controller"
application.register("search", SearchController)

import CharacterCounterController from "../javascript/controllers/character_counter_controller"
application.register("character-counter", CharacterCounterController)

import QuickAddModalController from "../javascript/controllers/quick_add_modal_controller"
application.register("quick-add-modal", QuickAddModalController)

import QuickAddFormController from "../javascript/controllers/quick_add_form_controller"
application.register("quick-add-form", QuickAddFormController)

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

//
import * as ActiveStorage from '@rails/activestorage'
ActiveStorage.start()
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'
