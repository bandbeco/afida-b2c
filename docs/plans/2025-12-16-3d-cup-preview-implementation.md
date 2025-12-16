# 3D Cup Preview Implementation Plan

**Date:** 2025-12-16
**Design Document:** `docs/plans/2025-12-16-3d-cup-preview-design.md`
**Estimated Tasks:** 12 tasks

---

## Prerequisites

Before starting implementation:

1. **Purchase the 3D model** from TurboSquid ($29):
   - URL: https://www.turbosquid.com/3d-models/coffee-cup-empty-8oz-takeout-2-1056690
   - Download OBJ format

2. **Convert to GLB format** using Blender:
   ```bash
   # Install Blender if needed (macOS)
   brew install --cask blender

   # Open Blender, import OBJ, export as GLB
   # File > Import > Wavefront (.obj)
   # Select the model
   # File > Export > glTF 2.0 (.glb)
   # Save to: public/models/hot_cup_8oz.glb
   ```

3. Create the models directory:
   ```bash
   mkdir -p public/models
   ```

---

## Task 1: Add Three.js Dependency

**File:** `package.json`

Add the Three.js library to the project dependencies.

**Steps:**
```bash
yarn add three@^0.170.0
```

**Verification:**
```bash
grep "three" package.json
# Expected: "three": "^0.170.0"
```

---

## Task 2: Create lib Directory Structure

**Files:**
- `app/frontend/javascript/lib/` (directory)

Create the directory for shared JavaScript libraries.

**Steps:**
```bash
mkdir -p app/frontend/javascript/lib
```

---

## Task 3: Create Cup Preview Library

**File:** `app/frontend/javascript/lib/cup_preview.js`

This module handles all Three.js scene setup, rendering, and texture management.

```javascript
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'

/**
 * CupPreview handles 3D rendering of a cup with custom textures.
 *
 * Usage:
 *   const preview = new CupPreview(canvasElement, { cupColor: 'kraft' })
 *   await preview.init()
 *   preview.setTexture(imageFile)
 *   preview.dispose() // cleanup
 */
export class CupPreview {
  constructor(canvas, options = {}) {
    this.canvas = canvas
    this.cupColor = options.cupColor || 'kraft'

    this.scene = null
    this.camera = null
    this.renderer = null
    this.controls = null
    this.cup = null
    this.animationId = null

    this.autoRotate = true
    this.autoRotateSpeed = 0.3 // radians per second
    this.interactionTimeout = null
    this.lastInteractionTime = 0

    this.isInitialized = false
    this.isDisposed = false
  }

  /**
   * Check if WebGL is supported in this browser
   */
  static isWebGLSupported() {
    try {
      const canvas = document.createElement('canvas')
      return !!(
        window.WebGLRenderingContext &&
        (canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
      )
    } catch (e) {
      return false
    }
  }

  /**
   * Initialize the 3D scene, camera, lighting, and load the cup model
   */
  async init() {
    if (this.isDisposed) return

    // Scene setup
    this.scene = new THREE.Scene()

    // Camera - positioned slightly above, looking down at cup
    const aspect = this.canvas.clientWidth / this.canvas.clientHeight
    this.camera = new THREE.PerspectiveCamera(45, aspect, 0.1, 1000)
    this.camera.position.set(0, 2, 5)
    this.camera.lookAt(0, 0, 0)

    // Renderer with transparency
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true,
      alpha: true
    })
    this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.outputColorSpace = THREE.SRGBColorSpace

    // Lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
    this.scene.add(ambientLight)

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8)
    directionalLight.position.set(-2, 4, 2)
    this.scene.add(directionalLight)

    // OrbitControls for drag-to-rotate
    this.controls = new OrbitControls(this.camera, this.canvas)
    this.controls.enableDamping = true
    this.controls.dampingFactor = 0.05
    this.controls.enableZoom = false
    this.controls.enablePan = false
    this.controls.minPolarAngle = Math.PI / 4  // Limit vertical rotation
    this.controls.maxPolarAngle = Math.PI / 2 + Math.PI / 12

    // Track user interaction to pause auto-rotate
    this.controls.addEventListener('start', () => this.onInteractionStart())
    this.controls.addEventListener('end', () => this.onInteractionEnd())

    // Load cup model
    await this.loadCupModel()

    // Handle window resize
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener('resize', this.resizeHandler)

    // Handle visibility change (pause when tab hidden)
    this.visibilityHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.visibilityHandler)

    this.isInitialized = true

    // Start render loop
    this.animate()
  }

  /**
   * Load the GLB cup model
   */
  async loadCupModel() {
    return new Promise((resolve, reject) => {
      const loader = new GLTFLoader()

      loader.load(
        '/models/hot_cup_8oz.glb',
        (gltf) => {
          this.cup = gltf.scene

          // Center and scale the model appropriately
          const box = new THREE.Box3().setFromObject(this.cup)
          const center = box.getCenter(new THREE.Vector3())
          this.cup.position.sub(center)

          // Scale to fit nicely in view
          const size = box.getSize(new THREE.Vector3())
          const maxDim = Math.max(size.x, size.y, size.z)
          const scale = 2 / maxDim
          this.cup.scale.setScalar(scale)

          this.scene.add(this.cup)
          resolve()
        },
        undefined,
        (error) => {
          console.error('Failed to load cup model:', error)
          reject(error)
        }
      )
    })
  }

  /**
   * Apply a texture from an uploaded image file
   */
  async setTexture(file) {
    if (!this.cup || this.isDisposed) return

    return new Promise((resolve, reject) => {
      const reader = new FileReader()

      reader.onload = (event) => {
        const textureLoader = new THREE.TextureLoader()

        textureLoader.load(
          event.target.result,
          (texture) => {
            texture.colorSpace = THREE.SRGBColorSpace
            texture.flipY = false

            // Check if image has transparency
            this.checkTransparency(file).then(hasTransparency => {
              if (hasTransparency) {
                // Composite onto base color
                this.applyCompositeTexture(texture)
              } else {
                // Apply directly
                this.applyTextureToMesh(texture)
              }
              resolve()
            })
          },
          undefined,
          (error) => {
            console.error('Failed to load texture:', error)
            reject(error)
          }
        )
      }

      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  /**
   * Check if an image file has transparency (PNG with alpha)
   */
  async checkTransparency(file) {
    if (!file.type.includes('png')) return false

    return new Promise((resolve) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        canvas.width = Math.min(img.width, 100) // Sample small area
        canvas.height = Math.min(img.height, 100)
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)

        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
        const data = imageData.data

        // Check alpha channel
        for (let i = 3; i < data.length; i += 4) {
          if (data[i] < 255) {
            resolve(true)
            return
          }
        }
        resolve(false)
      }
      img.onerror = () => resolve(false)
      img.src = URL.createObjectURL(file)
    })
  }

  /**
   * Composite uploaded texture onto base cup color
   */
  applyCompositeTexture(uploadedTexture) {
    // Get base color based on cup type
    const baseColor = this.cupColor === 'white' ? '#ffffff' : '#c9a66b' // kraft brown

    // Create canvas to composite
    const canvas = document.createElement('canvas')
    canvas.width = 2048
    canvas.height = 2048
    const ctx = canvas.getContext('2d')

    // Fill with base color
    ctx.fillStyle = baseColor
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    // Draw uploaded image on top
    const img = uploadedTexture.image
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height)

    // Create new texture from composite
    const compositeTexture = new THREE.CanvasTexture(canvas)
    compositeTexture.colorSpace = THREE.SRGBColorSpace
    compositeTexture.flipY = false

    this.applyTextureToMesh(compositeTexture)
  }

  /**
   * Apply texture to the cup mesh material
   */
  applyTextureToMesh(texture) {
    this.cup.traverse((child) => {
      if (child.isMesh) {
        child.material = new THREE.MeshStandardMaterial({
          map: texture,
          roughness: 0.7,
          metalness: 0.0
        })
      }
    })
  }

  /**
   * Handle user interaction start (pause auto-rotate)
   */
  onInteractionStart() {
    this.autoRotate = false
    this.lastInteractionTime = Date.now()

    if (this.interactionTimeout) {
      clearTimeout(this.interactionTimeout)
    }
  }

  /**
   * Handle user interaction end (schedule auto-rotate resume)
   */
  onInteractionEnd() {
    this.lastInteractionTime = Date.now()

    // Resume auto-rotate after 3 seconds of inactivity
    this.interactionTimeout = setTimeout(() => {
      this.autoRotate = true
    }, 3000)
  }

  /**
   * Animation loop
   */
  animate() {
    if (this.isDisposed) return

    this.animationId = requestAnimationFrame(() => this.animate())

    // Auto-rotate cup
    if (this.autoRotate && this.cup) {
      this.cup.rotation.y += this.autoRotateSpeed * (1 / 60) // ~60fps
    }

    this.controls.update()
    this.renderer.render(this.scene, this.camera)
  }

  /**
   * Handle window resize
   */
  handleResize() {
    if (this.isDisposed || !this.camera || !this.renderer) return

    // Debounce resize
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }

    this.resizeTimeout = setTimeout(() => {
      const width = this.canvas.clientWidth
      const height = this.canvas.clientHeight

      this.camera.aspect = width / height
      this.camera.updateProjectionMatrix()

      this.renderer.setSize(width, height)
    }, 100)
  }

  /**
   * Handle visibility change (pause when tab hidden)
   */
  handleVisibilityChange() {
    if (document.hidden) {
      if (this.animationId) {
        cancelAnimationFrame(this.animationId)
        this.animationId = null
      }
    } else if (this.isInitialized && !this.isDisposed) {
      this.animate()
    }
  }

  /**
   * Clean up all resources
   */
  dispose() {
    this.isDisposed = true

    // Stop animation
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }

    // Remove event listeners
    window.removeEventListener('resize', this.resizeHandler)
    document.removeEventListener('visibilitychange', this.visibilityHandler)

    // Clear timeouts
    if (this.interactionTimeout) {
      clearTimeout(this.interactionTimeout)
    }
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }

    // Dispose Three.js resources
    if (this.controls) {
      this.controls.dispose()
    }

    if (this.scene) {
      this.scene.traverse((object) => {
        if (object.geometry) {
          object.geometry.dispose()
        }
        if (object.material) {
          if (Array.isArray(object.material)) {
            object.material.forEach(m => {
              if (m.map) m.map.dispose()
              m.dispose()
            })
          } else {
            if (object.material.map) object.material.map.dispose()
            object.material.dispose()
          }
        }
      })
    }

    if (this.renderer) {
      this.renderer.dispose()
    }
  }
}
```

**Verification:**
```bash
ls app/frontend/javascript/lib/cup_preview.js
# Expected: file exists
```

---

## Task 4: Create Cup Preview Stimulus Controller

**File:** `app/frontend/javascript/controllers/cup_preview_controller.js`

This Stimulus controller handles DOM integration and communicates with the branded configurator.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "staticImage", "previewMessage"]

  static values = {
    cupColor: { type: String, default: "kraft" }
  }

  connect() {
    this.preview = null
    this.isWebGLSupported = false

    // Check WebGL support
    this.checkWebGLSupport()
  }

  async checkWebGLSupport() {
    // Lazy load the CupPreview module
    const { CupPreview } = await import("../lib/cup_preview.js")

    this.isWebGLSupported = CupPreview.isWebGLSupported()

    if (!this.isWebGLSupported) {
      // Silently degrade - keep showing static image
      console.log("WebGL not supported, using static image fallback")
    }
  }

  /**
   * Called when branded-configurator dispatches designUploaded event
   */
  async showPreview(event) {
    const { file } = event.detail

    if (!file) return

    // Check if file type is supported for preview (PNG/JPG only, not PDF/AI)
    const supportedTypes = ['image/png', 'image/jpeg', 'image/jpg']
    if (!supportedTypes.includes(file.type)) {
      this.showUnsupportedMessage()
      return
    }

    if (!this.isWebGLSupported) {
      // Fallback - just keep static image
      return
    }

    try {
      // Initialize preview if first time
      if (!this.preview) {
        const { CupPreview } = await import("../lib/cup_preview.js")

        this.preview = new CupPreview(this.canvasTarget, {
          cupColor: this.cupColorValue
        })

        await this.preview.init()
      }

      // Apply the uploaded texture
      await this.preview.setTexture(file)

      // Transition from static to 3D
      this.transitionToPreview()

    } catch (error) {
      console.error("Failed to initialize 3D preview:", error)
      // Fail silently - keep static image
    }
  }

  /**
   * Show message for unsupported file types (PDF/AI)
   */
  showUnsupportedMessage() {
    if (this.hasPreviewMessageTarget) {
      this.previewMessageTarget.textContent = "Preview available for JPG/PNG files"
      this.previewMessageTarget.classList.remove("hidden")
    }
  }

  /**
   * Animate transition from static image to 3D canvas
   */
  transitionToPreview() {
    // Fade out static image
    if (this.hasStaticImageTarget) {
      this.staticImageTarget.classList.add("opacity-0", "transition-opacity", "duration-300")

      setTimeout(() => {
        this.staticImageTarget.classList.add("hidden")
      }, 300)
    }

    // Fade in canvas
    if (this.hasCanvasTarget) {
      this.canvasTarget.classList.remove("hidden")
      this.canvasTarget.classList.add("opacity-0")

      // Force reflow
      this.canvasTarget.offsetHeight

      this.canvasTarget.classList.add("transition-opacity", "duration-300")
      this.canvasTarget.classList.remove("opacity-0")
    }

    // Hide unsupported message if shown
    if (this.hasPreviewMessageTarget) {
      this.previewMessageTarget.classList.add("hidden")
    }
  }

  /**
   * Reset to static image (called when configurator resets)
   */
  reset() {
    // Show static image
    if (this.hasStaticImageTarget) {
      this.staticImageTarget.classList.remove("hidden", "opacity-0")
    }

    // Hide canvas
    if (this.hasCanvasTarget) {
      this.canvasTarget.classList.add("hidden")
    }

    // Hide message
    if (this.hasPreviewMessageTarget) {
      this.previewMessageTarget.classList.add("hidden")
    }

    // Dispose preview to free memory
    if (this.preview) {
      this.preview.dispose()
      this.preview = null
    }
  }

  disconnect() {
    if (this.preview) {
      this.preview.dispose()
      this.preview = null
    }
  }
}
```

**Verification:**
```bash
ls app/frontend/javascript/controllers/cup_preview_controller.js
# Expected: file exists
```

---

## Task 5: Register Cup Preview Controller

**File:** `app/frontend/entrypoints/application.js`

Add the cup-preview controller to the lazy loading map.

**Find this section (around line 25-46):**
```javascript
const lazyControllers = {
  "analytics": () => import("../javascript/controllers/analytics_controller"),
  // ... other controllers ...
  "subscription-toggle": () => import("../javascript/controllers/subscription_toggle_controller")
}
```

**Add this line inside the object (alphabetically, after "carousel"):**
```javascript
  "cup-preview": () => import("../javascript/controllers/cup_preview_controller"),
```

**Full modified section:**
```javascript
const lazyControllers = {
  "analytics": () => import("../javascript/controllers/analytics_controller"),
  "carousel": () => import("../javascript/controllers/carousel_controller"),
  "cup-preview": () => import("../javascript/controllers/cup_preview_controller"),
  "branded-configurator": () => import("../javascript/controllers/branded_configurator_controller"),
  // ... rest of controllers
}
```

**Verification:**
```bash
grep "cup-preview" app/frontend/entrypoints/application.js
# Expected: "cup-preview": () => import("../javascript/controllers/cup_preview_controller"),
```

---

## Task 6: Modify Branded Configurator to Dispatch Event

**File:** `app/frontend/javascript/controllers/branded_configurator_controller.js`

Add event dispatch when design is successfully uploaded.

**Find the `handleDesignUpload` method (around line 380-409) and add the dispatch call:**

**Before (around line 406-408):**
```javascript
    this.clearError()
    this.showStepComplete('design')
    this.updateAddToCartButton()
```

**After:**
```javascript
    this.clearError()
    this.showStepComplete('design')
    this.updateAddToCartButton()

    // Dispatch event for 3D preview
    this.dispatch("designUploaded", {
      detail: { file }
    })
```

**Also add dispatch in `resetConfigurator` method (around line 612) to notify preview to reset:**

**Find the end of `resetConfigurator` method (around line 682) and add before the closing brace:**

```javascript
    // Notify 3D preview to reset
    this.dispatch("configuratorReset")
```

**Verification:**
```bash
grep -n "designUploaded" app/frontend/javascript/controllers/branded_configurator_controller.js
# Expected: Line with this.dispatch("designUploaded"
```

---

## Task 7: Update Branded Configurator View

**File:** `app/views/branded_products/_branded_configurator.html.erb`

Wrap the product image section with the cup-preview controller and add the canvas element.

**Find the left panel section (around lines 49-61):**
```erb
    <!-- Left: Product Images -->
    <div>
      <% image_source = @product.product_photo %>
      <% if image_source&.attached? %>
        <figure class="rounded-lg overflow-hidden shadow-lg">
          <%= image_tag image_source.variant(resize_to_limit: [600, 600]), alt: @product.name, class: "w-full h-auto" %>
        </figure>
      <% else %>
        <div class="w-full h-96 bg-gray-200 rounded-lg shadow-md flex items-center justify-center">
          <span class="text-gray-700">Image not available</span>
        </div>
      <% end %>
    </div>
```

**Replace with:**
```erb
    <!-- Left: Product Images / 3D Preview -->
    <div data-controller="cup-preview"
         data-cup-preview-cup-color-value="<%= @product.cup_color || 'kraft' %>"
         data-action="branded-configurator:designUploaded->cup-preview#showPreview branded-configurator:configuratorReset->cup-preview#reset">

      <% image_source = @product.product_photo %>
      <% if image_source&.attached? %>
        <!-- Static product photo (shown initially) -->
        <figure class="rounded-lg overflow-hidden shadow-lg" data-cup-preview-target="staticImage">
          <%= image_tag image_source.variant(resize_to_limit: [600, 600]), alt: @product.name, class: "w-full h-auto" %>
        </figure>
      <% else %>
        <div class="w-full h-96 bg-gray-200 rounded-lg shadow-md flex items-center justify-center" data-cup-preview-target="staticImage">
          <span class="text-gray-700">Image not available</span>
        </div>
      <% end %>

      <!-- 3D canvas (hidden until design uploaded) -->
      <canvas data-cup-preview-target="canvas"
              class="hidden w-full h-auto rounded-lg shadow-lg aspect-square">
      </canvas>

      <!-- Message for unsupported file types -->
      <p class="hidden mt-2 text-sm text-gray-500 text-center" data-cup-preview-target="previewMessage"></p>
    </div>
```

**Verification:**
```bash
grep -n "cup-preview" app/views/branded_products/_branded_configurator.html.erb
# Expected: Multiple lines with cup-preview controller, targets, and actions
```

---

## Task 8: Add cup_color Attribute to Product Model (Optional)

If you want to support different cup base colors (kraft brown vs white), add a column to products.

**Generate migration:**
```bash
rails generate migration AddCupColorToProducts cup_color:string
```

**Edit the migration to set default:**
```ruby
class AddCupColorToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :cup_color, :string, default: 'kraft'
  end
end
```

**Run migration:**
```bash
rails db:migrate
```

**Note:** This task is optional. If you skip it, change the view to use a hardcoded value:
```erb
data-cup-preview-cup-color-value="kraft"
```

---

## Task 9: Create System Test for 3D Preview

**File:** `test/system/cup_preview_test.rb`

```ruby
require "application_system_test_case"

class CupPreviewTest < ApplicationSystemTestCase
  setup do
    @acme_admin = users(:acme_admin)
    @product = products(:branded_double_wall_template)
  end

  test "3D preview shows after uploading PNG design" do
    sign_in_as @acme_admin
    visit product_path(@product)

    # Verify static image is visible initially
    assert_selector "[data-cup-preview-target='staticImage']", visible: true
    assert_selector "[data-cup-preview-target='canvas']", visible: false

    # Complete steps 1-3 to get to design upload
    click_button "12oz"
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='1000']").click
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Continue to next step"

    # Upload PNG design
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(
      Rails.root.join("test", "fixtures", "files", "test_logo.png")
    )

    # Wait for 3D preview to initialize and transition
    sleep 1  # Allow time for Three.js initialization

    # Canvas should now be visible (static image hidden)
    assert_selector "[data-cup-preview-target='canvas']", visible: true
  end

  test "PDF upload shows unsupported preview message" do
    sign_in_as @acme_admin
    visit product_path(@product)

    # Complete steps 1-3
    click_button "12oz"
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='1000']").click
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Continue to next step"

    # Upload PDF (not supported for 3D preview)
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(
      Rails.root.join("test", "fixtures", "files", "test_design.pdf")
    )

    # Should show message about unsupported format
    assert_text "Preview available for JPG/PNG files"

    # Static image should still be visible
    assert_selector "[data-cup-preview-target='staticImage']", visible: true
  end

  test "3D preview resets when configurator resets" do
    sign_in_as @acme_admin
    visit product_path(@product)

    # Complete full flow and add to cart
    click_button "12oz"
    find("[data-branded-configurator-target='quantityStep'] input[type='radio']", visible: false).click
    find("[data-quantity='1000']").click
    find("[data-branded-configurator-target='lidsStep'] input[type='radio']", visible: false).click
    click_button "Continue to next step"
    find("[data-branded-configurator-target='designStep'] input[type='radio']", visible: false).click
    find("[data-branded-configurator-target='designInput']").attach_file(
      Rails.root.join("test", "fixtures", "files", "test_logo.png")
    )

    # Wait for price to calculate
    assert_selector "[data-branded-configurator-target='total']", text: /£[1-9]/

    # Add to cart (triggers reset)
    click_button "Add to Cart"

    # After reset, static image should be visible again
    assert_selector "[data-cup-preview-target='staticImage']", visible: true
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
    assert_no_selector "h1", text: "Sign In"
  end
end
```

**Create test fixture file:**
```bash
# Create a simple 100x100 PNG for testing
# You can use any small PNG file, or create one with ImageMagick:
convert -size 100x100 xc:red test/fixtures/files/test_logo.png
```

**Verification:**
```bash
rails test test/system/cup_preview_test.rb
```

---

## Task 10: Create JavaScript Unit Tests (Optional)

**File:** `test/javascript/cup_preview_test.js`

If you have a JavaScript testing setup (Jest, Vitest, etc.), add unit tests for the CupPreview class.

```javascript
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { CupPreview } from '../../app/frontend/javascript/lib/cup_preview.js'

describe('CupPreview', () => {
  describe('isWebGLSupported', () => {
    it('returns true when WebGL is available', () => {
      // Mock WebGL context
      const mockCanvas = {
        getContext: vi.fn().mockReturnValue({})
      }
      vi.spyOn(document, 'createElement').mockReturnValue(mockCanvas)

      expect(CupPreview.isWebGLSupported()).toBe(true)
    })

    it('returns false when WebGL is not available', () => {
      const mockCanvas = {
        getContext: vi.fn().mockReturnValue(null)
      }
      vi.spyOn(document, 'createElement').mockReturnValue(mockCanvas)

      expect(CupPreview.isWebGLSupported()).toBe(false)
    })
  })
})
```

---

## Task 11: Add 3D Model File

**File:** `public/models/hot_cup_8oz.glb`

This requires manual steps:

1. Purchase model from TurboSquid (link in design doc)
2. Download OBJ format
3. Open Blender
4. Import OBJ: File > Import > Wavefront (.obj)
5. Verify UV mapping looks correct
6. Export GLB: File > Export > glTF 2.0 (.glb)
7. Save to `public/models/hot_cup_8oz.glb`

**Verification:**
```bash
ls -la public/models/hot_cup_8oz.glb
# Expected: File exists, reasonable size (few MB)
```

---

## Task 12: Manual Testing Checklist

After completing all tasks, test manually:

**Desktop browsers:**
- [ ] Chrome: 3D preview loads, rotates, drag works
- [ ] Firefox: Same as Chrome
- [ ] Safari: Same as Chrome
- [ ] Edge: Same as Chrome

**Mobile browsers:**
- [ ] iOS Safari: Touch drag to rotate works
- [ ] Android Chrome: Same as iOS

**File types:**
- [ ] PNG: Shows 3D preview
- [ ] JPG: Shows 3D preview
- [ ] PNG with transparency: Logo composited on kraft background
- [ ] PDF: Shows "Preview available for JPG/PNG" message
- [ ] AI: Shows message (same as PDF)

**Interactions:**
- [ ] Auto-rotation starts immediately
- [ ] Drag pauses auto-rotation
- [ ] After 3 seconds idle, auto-rotation resumes
- [ ] Vertical tilt is limited (can't flip cup)

**Edge cases:**
- [ ] Tab hidden: Animation pauses (check CPU usage)
- [ ] Window resize: Canvas resizes correctly
- [ ] Reset configurator: Returns to static image
- [ ] WebGL disabled: Static image remains (no errors)

---

## Summary

| Task | File | Type |
|------|------|------|
| 1 | package.json | Dependency |
| 2 | lib/ directory | Structure |
| 3 | cup_preview.js | New file |
| 4 | cup_preview_controller.js | New file |
| 5 | application.js | Modify |
| 6 | branded_configurator_controller.js | Modify |
| 7 | _branded_configurator.html.erb | Modify |
| 8 | Migration (optional) | Database |
| 9 | cup_preview_test.rb | New file |
| 10 | JavaScript tests (optional) | New file |
| 11 | hot_cup_8oz.glb | Asset |
| 12 | Manual testing | QA |

**Estimated implementation time:** Tasks are independent and can be done in any order after Task 1 (dependency).
