---
type: Plan
description: Implementation plan for a lids configuration step and an add-ons carousel with modal configurators in the branded product configurator.
status: shipped
timestamp: 2025-10-23
---

# Product Add-ons System Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Add BrandYour-style product add-ons and compatible lids selection to branded product configurator, enabling cross-sell and completing the order with complementary products.

**Architecture:** Optional lids configuration step (accordion step 4, cups only) with size-based lid matching, plus add-ons carousel with modal configurators for other branded products. Uses existing Swiper.js carousel and DaisyUI modal components.

**Tech Stack:** Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), Swiper.js, DaisyUI, TailwindCSS 4

---

## Phase 1: Lids Configuration Step

### Task 1: Add compatible lids helper and AJAX endpoint

**Files:**
- Create: `app/helpers/product_helper.rb`
- Create: `app/controllers/branded_products/lids_controller.rb`
- Create: `test/controllers/branded_products/lids_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write failing test**

In `test/controllers/branded_products/lids_controller_test.rb`:
```ruby
require "test_helper"

class BrandedProducts::LidsControllerTest < ActionDispatch::IntegrationTest
  test "returns compatible lids for 8oz cups" do
    get branded_products_compatible_lids_path, params: { size: "8oz" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["lids"].is_a?(Array)
    # Should return 80mm lids
    json["lids"].each do |lid|
      assert_match /80mm/, lid["name"]
    end
  end

  test "returns compatible lids for 12oz cups" do
    get branded_products_compatible_lids_path, params: { size: "12oz" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    # Should return 90mm lids
    json["lids"].each do |lid|
      assert_match /90mm/, lid["name"]
    end
  end

  test "returns empty array for invalid size" do
    get branded_products_compatible_lids_path, params: { size: "99oz" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal [], json["lids"]
  end

  test "returns lids with required attributes" do
    get branded_products_compatible_lids_path, params: { size: "8oz" }, as: :json

    json = JSON.parse(response.body)
    lid = json["lids"].first

    assert lid["id"].present?
    assert lid["name"].present?
    assert lid["price"].present?
    assert lid["pac_size"].present?
    assert lid["sku"].present?
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/controllers/branded_products/lids_controller_test.rb`
Expected: FAIL (controller doesn't exist)

**Step 3: Create product helper**

In `app/helpers/product_helper.rb`:
```ruby
module ProductHelper
  # Map cup sizes to compatible lid sizes
  LID_SIZE_MAP = {
    '4oz' => '62mm',
    '6oz' => '80mm',
    '8oz' => '80mm',
    '10oz' => '90mm',
    '12oz' => '90mm',
    '16oz' => '90mm',
    '20oz' => '90mm'
  }.freeze

  def compatible_lids_for_cup(cup_size)
    lid_size = LID_SIZE_MAP[cup_size]
    return [] unless lid_size

    # Fetch from Hot Cups Extras category
    hot_cups_extras = Category.find_by(slug: 'hot-cups-extras')
    return [] unless hot_cups_extras

    hot_cups_extras.products
                   .where("name LIKE ?", "%#{lid_size}%")
                   .where("name LIKE ?", "%Lid%")
                   .includes(:active_variants, image_attachment: :blob)
  end
end
```

**Step 4: Create controller**

In `app/controllers/branded_products/lids_controller.rb`:
```ruby
module BrandedProducts
  class LidsController < ApplicationController
    include ProductHelper
    allow_unauthenticated_access

    def compatible_lids
      cup_size = params[:size]
      lids = compatible_lids_for_cup(cup_size)

      render json: {
        lids: lids.map { |lid|
          variant = lid.active_variants.first
          {
            id: lid.id,
            name: lid.name,
            slug: lid.slug,
            image_url: lid.image.attached? ? url_for(lid.image.variant(resize_to_limit: [200, 200])) : nil,
            price: variant&.price || 0,
            pac_size: variant&.pac_size || 1000,
            sku: variant&.sku,
            variant_id: variant&.id
          }
        }
      }
    end
  end
end
```

**Step 5: Add routes**

In `config/routes.rb`, add to branded_products namespace:
```ruby
  namespace :branded_products do
    post "calculate_price", to: "configurator#calculate_price"
    get "available_options/:product_id", to: "configurator#available_options", as: :available_options
    get "compatible_lids", to: "lids#compatible_lids"
  end
```

**Step 6: Run tests to verify they pass**

Run: `rails test test/controllers/branded_products/lids_controller_test.rb`
Expected: PASS (4 tests)

**Step 7: Commit**

```bash
git add .
git commit -m "Add compatible lids helper and AJAX endpoint

- Add LID_SIZE_MAP for cup size to lid size mapping
- Add compatible_lids_for_cup helper method
- Add BrandedProducts::LidsController with compatible_lids action
- Returns lid data with images, pricing, and SKU info
- Tests for different cup sizes and validation

Tests: 4 tests passing"
```

---

### Task 2: Add lids step to configurator UI

**Files:**
- Modify: `app/views/products/_branded_configurator.html.erb`
- Modify: `app/frontend/javascript/controllers/branded_configurator_controller.js`

**Step 1: Add lids step to accordion**

In `app/views/products/_branded_configurator.html.erb`, after quantity step:
```erb
        <!-- Step 4: Add Matching Lids (Optional) -->
        <div class="collapse collapse-arrow bg-base-200" data-branded-configurator-target="lidsStep">
          <input type="radio" name="config-accordion" />
          <div class="collapse-title text-lg font-semibold flex items-center gap-2">
            <span class="flex items-center justify-center w-6 h-6 rounded-full bg-gray-300 text-white text-sm font-bold" data-branded-configurator-target="lidsIndicator">4</span>
            Add Matching Lids (Optional)
          </div>
          <div class="collapse-content">
            <div class="pt-4">
              <p class="text-sm text-gray-600 mb-4">Complete your order with compatible lids</p>

              <div id="lids-loading" class="text-center py-8" style="display:none;">
                <span class="loading loading-spinner loading-lg"></span>
              </div>

              <div id="lids-grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4" data-branded-configurator-target="lidsContainer">
                <!-- Lids will be loaded here via AJAX -->
              </div>

              <button type="button"
                      class="btn btn-ghost mt-4"
                      data-action="click->branded-configurator#skipLids">
                Skip - No lids needed
              </button>
            </div>
          </div>
        </div>

        <!-- Step 5: Upload Design -->
        <div class="collapse collapse-arrow bg-base-200" data-branded-configurator-target="designStep">
          <input type="radio" name="config-accordion" />
          <div class="collapse-title text-lg font-semibold flex items-center gap-2">
            <span class="flex items-center justify-center w-6 h-6 rounded-full bg-gray-300 text-white text-sm font-bold" data-branded-configurator-target="designIndicator">5</span>
            Upload Your Design
          </div>
```

**Step 2: Update Stimulus controller targets**

In `branded_configurator_controller.js`:
```javascript
  static targets = [
    // ... existing targets
    "lidsStep",
    "lidsIndicator",
    "lidsContainer"
  ]
```

**Step 3: Add loadCompatibleLids method**

```javascript
  async loadCompatibleLids() {
    if (!this.selectedSize) return

    // Show loading state
    document.getElementById('lids-loading').style.display = 'block'
    this.lidsContainerTarget.innerHTML = ''

    try {
      const response = await fetch(`/branded_products/compatible_lids?size=${this.selectedSize}`)
      const data = await response.json()

      document.getElementById('lids-loading').style.display = 'none'

      if (data.lids.length === 0) {
        this.lidsContainerTarget.innerHTML = '<p class="text-gray-500 col-span-full text-center py-8">No compatible lids available for this size</p>'
        return
      }

      // Render lid cards
      data.lids.forEach(lid => {
        this.lidsContainerTarget.appendChild(this.createLidCard(lid))
      })
    } catch (error) {
      console.error('Failed to load compatible lids:', error)
      document.getElementById('lids-loading').style.display = 'none'
      this.lidsContainerTarget.innerHTML = '<p class="text-error col-span-full text-center py-8">Failed to load lids. Please try again.</p>'
    }
  }

  createLidCard(lid) {
    const card = document.createElement('div')
    card.className = 'card bg-white border-2 border-gray-200 hover:border-primary transition'
    card.innerHTML = `
      <figure class="p-4">
        ${lid.image_url ?
          `<img src="${lid.image_url}" alt="${lid.name}" class="w-full h-32 object-contain" />` :
          '<div class="w-full h-32 bg-gray-100 flex items-center justify-center"><span class="text-4xl">📦</span></div>'
        }
      </figure>
      <div class="card-body p-4">
        <h3 class="card-title text-sm">${lid.name}</h3>
        <p class="text-lg font-bold">£${parseFloat(lid.price).toFixed(2)}</p>
        <p class="text-xs text-gray-500">Pack of ${lid.pac_size.toLocaleString()}</p>

        <select class="select select-sm select-bordered w-full mt-2" data-lid-quantity="${lid.sku}">
          ${this.generateLidQuantityOptions(lid.pac_size, this.selectedQuantity).map(q =>
            `<option value="${q.value}">${q.label}</option>`
          ).join('')}
        </select>

        <button class="btn btn-primary btn-sm mt-2"
                data-action="click->branded-configurator#addLidToCart"
                data-lid-sku="${lid.sku}"
                data-lid-name="${lid.name}">
          + Add
        </button>
      </div>
    `
    return card
  }

  generateLidQuantityOptions(pac_size, cupQuantity) {
    // Generate pack multiples up to 10 packs
    const options = []
    for (let i = 1; i <= 10; i++) {
      const quantity = pac_size * i
      const numPacks = i
      options.push({
        value: quantity,
        label: `${quantity.toLocaleString()} units (${numPacks} ${numPacks === 1 ? 'pack' : 'packs'})`,
        selected: quantity === cupQuantity
      })
    }
    return options
  }
```

**Step 4: Update selectQuantity to load lids**

```javascript
  selectQuantity(event) {
    // ... existing code ...

    this.selectedQuantity = parseInt(event.currentTarget.dataset.quantity)
    this.updateUrl()
    this.showStepComplete('quantity')

    // Load compatible lids for next step
    this.loadCompatibleLids()

    this.calculatePrice()
  }
```

**Step 5: Add skipLids and addLidToCart methods**

```javascript
  skipLids(event) {
    // Mark step complete and move to design
    this.showStepComplete('lids')
  }

  async addLidToCart(event) {
    const button = event.currentTarget
    const sku = button.dataset.lidSku
    const name = button.dataset.lidName
    const quantitySelect = button.closest('.card-body').querySelector('select')
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
            variant_sku: sku,
            quantity: quantity
          }
        })
      })

      if (response.ok) {
        // Process turbo stream to update basket counter
        const text = await response.text()
        if (text) {
          Turbo.renderStreamMessage(text)
        }

        // Show success feedback
        button.textContent = '✓ Added'
        button.classList.remove('btn-primary')
        button.classList.add('btn-success')

        // Reset after 2 seconds
        setTimeout(() => {
          button.textContent = '+ Add'
          button.classList.remove('btn-success')
          button.classList.add('btn-primary')
          button.disabled = false
        }, 2000)
      } else {
        throw new Error('Failed to add lid')
      }
    } catch (error) {
      this.showError(`Failed to add ${name}`)
      button.disabled = false
      button.textContent = '+ Add'
    }
  }
```

**Step 6: Update showStepComplete to handle lids**

```javascript
  showStepComplete(step) {
    // ... existing code ...

    // Update step map to include lids
    const stepMap = { size: 'finish', finish: 'quantity', quantity: 'lids', lids: 'design' }

    // ... rest of method
  }
```

**Step 7: Test manually**

- Load configurator, select size and quantity
- Verify lids load via AJAX
- Verify correct lids shown for size
- Verify quantity pre-selected to match cups
- Verify "+ Add" adds lid to cart

**Step 8: Commit**

```bash
git add .
git commit -m "Add lids configuration step to branded configurator

- Add ProductHelper with LID_SIZE_MAP (cup size → lid size)
- Add compatible_lids_for_cup helper method
- Add BrandedProducts::LidsController with AJAX endpoint
- Add lids accordion step (optional, step 4)
- Load compatible lids when quantity selected
- Show lid cards with image, price, quantity dropdown
- Auto-match lid quantity to cup quantity
- Add lids as separate cart items
- Skip button to bypass lids

Tests: Lids controller tests passing"
```

---

## Phase 2: Add-ons Carousel

### Task 3: Add Swiper carousel for add-on products

**Files:**
- Modify: `app/views/products/_branded_configurator.html.erb`
- Modify: `app/controllers/products_controller.rb`
- Create: `app/views/products/_addon_carousel.html.erb`

**Step 1: Update ProductsController to load add-on products**

In `app/controllers/products_controller.rb`:
```ruby
  def show
    @product = Product.find_by!(slug: params[:id])

    if @product.customizable_template?
      service = BrandedProductPricingService.new(@product)
      @available_sizes = service.available_sizes
      @quantity_tiers = service.available_quantities(@available_sizes.first)

      # Load other branded products for add-ons carousel
      @addon_products = Product.customizable_template
                              .where.not(id: @product.id)
                              .includes(:branded_product_prices, image_attachment: :blob)
                              .order(:sort_order)
                              .limit(10)
    # ... rest of method
```

**Step 2: Create add-on carousel partial**

In `app/views/products/_addon_carousel.html.erb`:
```erb
<% if addon_products.any? %>
  <div class="mt-12 border-t pt-8">
    <h2 class="text-2xl font-bold mb-6">Complete your order with add-ons</h2>

    <div class="swiper addon-carousel" data-controller="carousel">
      <div class="swiper-wrapper">
        <% addon_products.each do |addon| %>
          <div class="swiper-slide">
            <div class="card bg-white border-2 border-gray-200 hover:border-primary transition h-full">
              <figure class="p-4">
                <% if addon.image.attached? %>
                  <%= image_tag addon.image.variant(resize_to_limit: [300, 300]),
                               alt: addon.name,
                               class: "w-full h-48 object-contain" %>
                <% else %>
                  <div class="w-full h-48 bg-gray-100 flex items-center justify-center">
                    <span class="text-6xl">📦</span>
                  </div>
                <% end %>
              </figure>

              <div class="card-body">
                <h3 class="card-title text-lg"><%= addon.name %></h3>

                <% min_price = addon.branded_product_prices.minimum(:price_per_unit) %>
                <% if min_price %>
                  <p class="text-lg font-bold text-primary">
                    from £<%= sprintf("%.3f", min_price) %>/unit
                  </p>
                <% end %>

                <% min_qty = addon.branded_product_prices.minimum(:quantity_tier) %>
                <% if min_qty %>
                  <p class="text-sm text-gray-600">
                    Min: <%= number_with_delimiter(min_qty) %> units
                  </p>
                <% end %>

                <button class="btn btn-primary btn-sm mt-4"
                        data-action="click->addon#openModal"
                        data-product-id="<%= addon.id %>"
                        data-product-name="<%= addon.name %>"
                        data-product-slug="<%= addon.slug %>">
                  Configure →
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Navigation -->
      <div class="swiper-button-prev"></div>
      <div class="swiper-button-next"></div>
    </div>
  </div>
<% end %>
```

**Step 3: Add carousel to branded configurator**

In `_branded_configurator.html.erb`, before closing divs:
```erb
      <!-- Add-ons Carousel -->
      <%= render "products/addon_carousel", addon_products: @addon_products || [] %>
```

**Step 4: Update carousel controller for add-ons**

Verify existing `carousel_controller.js` works with addon-carousel class, or create addon-specific config.

**Step 5: Test carousel**

- Load branded product page
- Verify carousel appears below configurator
- Verify shows other branded products
- Verify navigation arrows work
- Verify responsive (3 on desktop, 2 on tablet, 1 on mobile)

**Step 6: Commit**

```bash
git add .
git commit -m "Add add-ons carousel to branded configurator

- Load other customizable products in ProductsController
- Create addon_carousel partial with Swiper carousel
- Show product images, pricing, minimum quantities
- Configure buttons (modal integration next)
- Responsive: 3 cards desktop, 2 tablet, 1 mobile

Add-ons: Cross-sell other branded products"
```

---

## Phase 3: Modal Configurator

### Task 4: Create addon Stimulus controller and modal

**Files:**
- Create: `app/frontend/javascript/controllers/addon_controller.js`
- Modify: `app/views/products/_branded_configurator.html.erb`
- Modify: `app/controllers/products_controller.rb`

**Step 1: Create addon Stimulus controller**

In `app/frontend/javascript/controllers/addon_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "configuratorFrame", "modalTitle"]

  openModal(event) {
    const productSlug = event.currentTarget.dataset.productSlug
    const productName = event.currentTarget.dataset.productName

    // Update modal title
    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = `Configure ${productName}`
    }

    // Load configurator in turbo frame
    const frameHtml = `<turbo-frame id="addon-configurator-frame" src="/product/${productSlug}?modal=true"></turbo-frame>`
    this.configuratorFrameTarget.innerHTML = frameHtml

    // Open modal
    document.getElementById('addon-modal').showModal()

    // Listen for addon added event to close modal
    this.boundCloseHandler = this.handleAddonAdded.bind(this)
    window.addEventListener('addon:added', this.boundCloseHandler)
  }

  closeModal() {
    document.getElementById('addon-modal').close()

    // Clear frame
    this.configuratorFrameTarget.innerHTML = ''

    // Remove event listener
    if (this.boundCloseHandler) {
      window.removeEventListener('addon:added', this.boundCloseHandler)
    }
  }

  handleAddonAdded(event) {
    // Close modal when addon is added to cart
    this.closeModal()
  }
}
```

**Step 2: Add modal HTML to configurator**

In `_branded_configurator.html.erb`, after drawer structure:
```erb
<!-- Add-on Product Modal -->
<dialog id="addon-modal" class="modal" data-controller="addon" data-addon-target="modal">
  <div class="modal-box max-w-6xl w-full max-h-[90vh] overflow-y-auto">
    <form method="dialog">
      <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
              data-action="click->addon#closeModal">✕</button>
    </form>

    <h3 class="font-bold text-2xl mb-6" data-addon-target="modalTitle">
      Configure Add-on Product
    </h3>

    <div data-addon-target="configuratorFrame">
      <!-- Turbo frame will load configurator here -->
    </div>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button data-action="click->addon#closeModal">close</button>
  </form>
</dialog>
```

**Step 3: Update ProductsController for modal rendering**

```ruby
  def show
    @product = Product.find_by!(slug: params[:id])

    # Check if this is for modal display
    @in_modal = params[:modal] == 'true'

    if @product.customizable_template?
      # ... existing code ...

      if @in_modal
        # Render configurator without layout for modal
        render partial: 'branded_configurator_modal',
               locals: { product: @product }
        return
      end
    end
    # ... rest
  end
```

**Step 4: Create modal-specific configurator partial**

In `app/views/products/_branded_configurator_modal.html.erb`:
```erb
<div data-controller="branded-configurator"
     data-branded-configurator-product-id-value="<%= product.id %>"
     data-branded-configurator-vat-rate-value="0.2"
     data-branded-configurator-in-modal-value="true">

  <!-- Same configurator content but without drawer wrapper -->
  <!-- No lids step (prevent nested add-ons) -->
  <!-- No add-ons carousel (prevent infinite nesting) -->
  <!-- Modified "Add to Cart" to dispatch addon:added event -->

</div>
```

**Step 5: Modify branded_configurator for modal mode**

Update `addToCart` method to check if in modal:
```javascript
  static values = {
    productId: Number,
    vatRate: { type: Number, default: 0.2 },
    inModal: { type: Boolean, default: false }
  }

  async addToCart(event) {
    // ... existing add to cart logic ...

    if (response.ok) {
      // ... turbo stream processing ...

      if (this.inModalValue) {
        // In modal: dispatch event and don't try to open drawer
        window.dispatchEvent(new CustomEvent('addon:added'))
      } else {
        // Normal flow: open drawer
        // ... existing drawer code ...
      }
    }
  }
```

**Step 6: Test modal flow**

- Open branded cups configurator
- Scroll to add-ons carousel
- Click "Configure →" on pizza boxes
- Verify modal opens with pizza box configurator
- Configure pizza boxes and add to cart
- Verify modal closes
- Verify basket counter updated
- Verify can continue with cups configurator

**Step 7: Commit**

```bash
git add .
git commit -m "Add modal configurator for add-on products

- Create addon Stimulus controller for modal management
- Add DaisyUI modal with turbo-frame loading
- Create branded_configurator_modal partial (no nested add-ons)
- Update ProductsController to render for modal
- Dispatch addon:added event to close modal
- Modal closes after successful add to cart
- Basket counter updates via Turbo Stream

Add-ons: Full configurator experience in modal"
```

---

## Phase 4: Testing & Polish

### Task 5: Add system tests for add-ons workflow

**Files:**
- Create: `test/system/product_addons_test.rb`

**Step 1: Create system test**

```ruby
require "application_system_test_case"

class ProductAddonsTest < ApplicationSystemTestCase
  test "can add compatible lids during cup configuration" do
    visit product_path(products(:double_wall_branded_template))

    # Configure cup
    click_button "12oz"
    click_button "Matt"
    within "[data-quantity='5000']" do
      click
    end

    # Lids step should open and show compatible lids
    assert_selector "h3", text: "Add Matching Lids"
    assert_selector ".lid-card", minimum: 1

    # Add a lid
    within first(".lid-card") do
      click_button "+ Add"
    end

    # Verify success feedback
    assert_selector "button", text: "✓ Added"

    # Can skip lids
    click_button "Skip - No lids needed"

    # Upload design and complete
    attach_file "design", Rails.root.join("test/fixtures/files/test_design.pdf")
    click_button "Add to Cart"
  end

  test "can add addon product via modal" do
    visit product_path(products(:double_wall_branded_template))

    # Scroll to add-ons carousel
    within ".addon-carousel" do
      click_button "Configure", match: :first
    end

    # Modal should open
    assert_selector "dialog#addon-modal[open]"

    # Configure addon product in modal
    # ... configuration steps ...

    # Add to cart closes modal
    click_button "Add to Cart"
    assert_no_selector "dialog#addon-modal[open]"
  end
end
```

**Step 2: Run tests**

**Step 3: Commit**

```bash
git add .
git commit -m "Add system tests for add-ons workflow

- Test lids configuration step
- Test modal configurator for add-ons
- Test skip lids functionality
- Verify cart updates and modal behavior

Tests: Add-ons system tests"
```

---

### Task 6: Update step numbers throughout

**Files:**
- Modify: All step references in configurator
- Update validation messages
- Update documentation

**Commit:**

```bash
git commit -m "Update step numbers: Size(1) Finish(2) Quantity(3) Lids(4) Design(5)

- Updated all step indicators
- Updated validation messages
- Updated helper text
- Lids step optional (can skip)

Steps: Renumbered to include lids"
```

---

## Implementation Complete!

This plan provides **6 comprehensive tasks** covering:

✅ **Phase 1**: Compatible lids configuration step
✅ **Phase 2**: Add-ons carousel with Swiper
✅ **Phase 3**: Modal configurator for add-ons
✅ **Phase 4**: Testing and polish

Each task follows the established TDD approach with detailed implementation steps.

**Total estimated time**: 4-6 hours

The plan is ready for execution!

---

## Additional Branded Product Templates

Add these templates to match the printable products table:
- Single Wall Cold Cups (min: 30,000)
- Clear Recyclable Cups (min: 30,000)
- Ice Cream Cups (min: 50,000)
- Greaseproof Paper (min: 6,000)
- Pizza Boxes (min: 5,000)
- Kraft Containers (min: 10,000)
- Kraft Bags (min: 10,000)

Update `db/seeds/branded_product_pricing.rb` to create all templates.
Add basic pricing tiers for each.

Estimated: 1 hour
