# 3D Cup Preview for Branded Product Configurator

**Date:** 2025-12-16
**Status:** Draft
**Author:** Claude + Laurent

## Overview

Add an interactive 3D preview to the branded product configurator that shows customers their uploaded design wrapped onto a cup in real-time. This replaces the static product photo when a design is uploaded, giving customers instant visual feedback before ordering.

This feature provides a competitive advantage over competitors like BrandYour who don't offer real-time 3D previews.

## User Flow

1. User progresses through Steps 1-3 (size, quantity, lids)
2. Left panel shows static product photo throughout
3. User uploads design file in Step 4
4. Left panel transitions (fade/crossfade) to 3D preview
5. Cup auto-rotates slowly to showcase the design
6. User can drag to rotate manually; auto-rotation pauses
7. After 3 seconds of inactivity, auto-rotation resumes

**Fallback:** If WebGL isn't supported (<1% of browsers), keep showing the static photo silently (no error message).

## Technical Architecture

### New Files

| File | Purpose |
|------|---------|
| `app/frontend/javascript/lib/cup_preview.js` | Three.js scene setup, lighting, rendering, texture handling |
| `app/frontend/javascript/controllers/cup_preview_controller.js` | Stimulus controller for DOM integration |
| `public/models/hot_cup_8oz.glb` | 3D cup model (converted from purchased TurboSquid model) |

### Modified Files

| File | Change |
|------|--------|
| `app/views/branded_products/_branded_configurator.html.erb` | Add canvas element, wrap image in preview container |
| `app/frontend/javascript/controllers/branded_configurator_controller.js` | Dispatch event on successful design upload |
| `app/frontend/entrypoints/application.js` | Register `cup-preview` controller |
| `package.json` | Add `three` dependency |

### Dependencies

```json
{
  "three": "^0.170.0"
}
```

Bundle size impact: ~150KB gzipped (lazy-loaded only on branded product pages).

## 3D Scene Setup

### Scene Composition

- **Camera:** Perspective camera, positioned slightly above and in front of the cup (like looking down at a cup on a table)
- **Lighting:**
  - One ambient light (soft overall illumination)
  - One directional light from upper-left (creates gentle shadows)
- **Background:** Transparent - blends into existing page background
- **Cup:** Purchased 3D model with uploaded image as texture

### Texture Mapping

The uploaded image wraps horizontally around the cylinder using the model's existing UV mapping.

For images with transparency (logos):
1. Create a base texture (kraft brown or white, based on product)
2. Composite the uploaded image onto it
3. Apply the combined texture to the cup

### Rendering

- Canvas fills the existing product photo container (~600×600px desktop, responsive)
- Handles retina displays automatically
- Render loop pauses when browser tab is hidden (battery saving)

## Interaction & Animation

### Auto-rotation

- Rotates around Y-axis at ~0.3 radians/second (full rotation every ~20 seconds)
- Smooth, continuous motion using `requestAnimationFrame`

### Drag to Rotate

- Horizontal drag spins the cup
- Vertical drag tilts slightly (limited to ±15°)
- Uses Three.js `OrbitControls` with constrained axes
- Smooth damping so cup "coasts" when released

### Mode Transitions

- First user interaction → auto-rotation stops immediately
- 3 seconds of no interaction → auto-rotation fades back in gradually

### Mobile Touch

- Single finger drag to rotate
- Touch events handled by OrbitControls automatically
- Pinch-to-zoom disabled for simplicity

## Integration with Existing Configurator

### HTML Structure

```erb
<div data-controller="cup-preview"
     data-cup-preview-cup-color-value="kraft">

  <!-- Static product photo (shown initially) -->
  <figure data-cup-preview-target="staticImage">
    <%= image_tag ... %>
  </figure>

  <!-- 3D canvas (hidden until design uploaded) -->
  <canvas data-cup-preview-target="canvas"
          class="hidden w-full h-auto rounded-lg shadow-lg">
  </canvas>
</div>
```

### Controller Communication

When `branded_configurator_controller.js` handles a successful file upload:

```javascript
this.dispatch("designUploaded", {
  detail: { file: uploadedFile }
})
```

The `cup_preview_controller.js` listens via:

```html
data-action="branded-configurator:designUploaded->cup-preview#showPreview"
```

### Transition Effect

- Static image fades out (opacity 0 over 300ms)
- Canvas fades in simultaneously
- CSS handles transitions

## Edge Cases & Error Handling

### Unsupported Browsers (WebGL)

- Detect with `WebGLRenderingContext` check on controller connect
- If unsupported: keep static image, skip 3D entirely
- Graceful degradation - no error message shown

### File Type Support

| File Type | Preview Support |
|-----------|-----------------|
| PNG | Full support |
| JPG/JPEG | Full support |
| PDF | Not supported - show message: "Preview available for JPG/PNG files" |
| AI | Not supported - show message |

Future enhancement: server-side PDF/AI conversion.

### Transparent PNGs

- Detect transparency in uploaded image
- Composite onto base texture (kraft brown or white based on product data)
- Apply combined texture to cup

### Resize Handling

- On window resize, update camera aspect ratio and renderer size
- Debounce resize handler (100ms)

### Memory Cleanup

- When user navigates away or resets configurator, dispose:
  - Geometry
  - Textures
  - Renderer
- Prevents memory leaks on single-page navigation

## 3D Model

### Source

- **Model:** Coffee Cup Empty 8oz Takeout 2
- **Vendor:** TurboSquid
- **URL:** https://www.turbosquid.com/3d-models/coffee-cup-empty-8oz-takeout-2-1056690
- **Price:** $29 (one-time)
- **License:** TurboSquid Standard License (allows commercial web use)

### Specifications

- Polygons: 5,664
- Vertices: 5,666
- UV Mapped: Yes
- Textures: 6144×6144 PNG included

### Conversion

The model comes in 3ds Max, FBX, and OBJ formats. Convert to GLB (web-friendly) using:

1. Import OBJ into Blender (free)
2. Verify UV mapping is intact
3. Export as GLB with embedded textures
4. Place in `public/models/hot_cup_8oz.glb`

## MVP Scope

### Included

- 3D preview for hot cups (8oz model)
- PNG/JPG upload support
- Auto-rotate + drag interaction
- Transparent PNG handling with base texture
- WebGL fallback (static image)
- Memory cleanup

### Not Included (Future)

- PDF/AI file preview (requires server-side conversion)
- Multiple cup sizes (8oz, 12oz, 16oz models)
- Multiple product types (cold cups, boxes, bags)
- Lid on the cup
- Zoom controls

## Implementation Notes

### Performance Considerations

- Lazy-load Three.js only on branded product pages
- Low-poly model (5.6k polys) renders efficiently
- Single texture, minimal draw calls
- Pause render loop when tab hidden

### Testing

- Test on Chrome, Safari, Firefox, Edge
- Test on iOS Safari and Android Chrome
- Test WebGL fallback in legacy browsers
- Test memory cleanup on navigation

---

## Appendix: File Structure

```
app/
  frontend/
    javascript/
      lib/
        cup_preview.js           # Three.js scene, rendering, textures
      controllers/
        cup_preview_controller.js    # Stimulus controller
        branded_configurator_controller.js  # (modified)
    entrypoints/
      application.js             # (modified - register controller)
  views/
    branded_products/
      _branded_configurator.html.erb  # (modified - add canvas)

public/
  models/
    hot_cup_8oz.glb              # Converted 3D model

package.json                     # (modified - add three)
```
