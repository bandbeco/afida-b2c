# Research: 3D Cup Preview

**Feature**: 016-3d-cup-preview
**Date**: 2025-12-21
**Status**: Complete

## Research Topics

### 1. Three.js Integration with Vite/Stimulus

**Decision**: Use Three.js with dynamic imports for lazy loading

**Rationale**:
- Three.js is the industry-standard WebGL library with excellent documentation
- Dynamic `import()` allows lazy loading only when 3D preview is needed
- Vite handles tree-shaking to minimize bundle size
- OrbitControls from Three.js examples provides touch/mouse rotation out of box

**Alternatives Considered**:
- **Babylon.js**: More features but larger bundle (~500KB vs ~150KB)
- **CSS 3D Transforms**: Simpler but cannot apply textures to 3D models
- **Pre-rendered mockups**: No real-time preview, requires server-side processing

**Implementation Pattern**:
```javascript
// Lazy load Three.js only when needed
const { CupPreview } = await import("../lib/cup_preview.js")
```

### 2. 3D Model Format and Source

**Decision**: Purchase GLB model from TurboSquid, convert with Blender

**Rationale**:
- GLB (binary glTF) is the optimal web format - compact, fast loading, widely supported
- TurboSquid offers UV-mapped models ready for texture application
- $29 one-time cost is minimal compared to modeling time
- Standard License allows commercial web use

**Selected Model**:
- Coffee Cup Empty 8oz Takeout 2
- URL: https://www.turbosquid.com/3d-models/coffee-cup-empty-8oz-takeout-2-1056690
- Polygons: 5,664 (web-friendly)
- UV Mapped: Yes (required for texture wrapping)

**Conversion Process**:
1. Download OBJ format from TurboSquid
2. Import into Blender (free)
3. Export as GLB with embedded textures
4. Place in `public/models/hot_cup_8oz.glb`

### 3. Texture Application for Uploaded Images

**Decision**: Client-side texture processing using Canvas API + Three.js TextureLoader

**Rationale**:
- No server round-trip = instant preview
- Canvas API can composite transparency onto base colors
- FileReader provides immediate access to uploaded file data
- Three.js TextureLoader handles image-to-texture conversion

**Pattern for Transparent PNGs**:
```javascript
// Detect transparency and composite onto base cup color
const canvas = document.createElement('canvas')
const ctx = canvas.getContext('2d')
ctx.fillStyle = cupBaseColor // kraft brown or white
ctx.fillRect(0, 0, canvas.width, canvas.height)
ctx.drawImage(uploadedImage, 0, 0)
const compositeTexture = new THREE.CanvasTexture(canvas)
```

### 4. Stimulus Controller Communication Pattern

**Decision**: Use Stimulus event dispatch for controller-to-controller communication

**Rationale**:
- Follows Hotwire conventions (no custom event systems)
- Decouples branded-configurator from cup-preview
- HTML data-action attribute wires up listeners declaratively
- Easy to test in isolation

**Event Contract**:
```javascript
// branded_configurator_controller.js dispatches:
this.dispatch("designUploaded", { detail: { file } })
this.dispatch("configuratorReset")

// cup_preview_controller.js listens via HTML:
// data-action="branded-configurator:designUploaded->cup-preview#showPreview"
```

### 5. WebGL Detection and Fallback Strategy

**Decision**: Silent fallback - keep static image if WebGL unavailable

**Rationale**:
- Only ~1% of browsers lack WebGL support
- Error messages would confuse users on older devices
- Graceful degradation maintains core functionality (ordering still works)
- Detection is fast and non-intrusive

**Detection Pattern**:
```javascript
static isWebGLSupported() {
  try {
    const canvas = document.createElement('canvas')
    return !!(window.WebGLRenderingContext &&
      (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')))
  } catch (e) {
    return false
  }
}
```

### 6. Performance Optimization Strategies

**Decision**: Implement multiple optimization techniques

**Rationale**:
- Battery and CPU conservation improves user experience
- Visibility API prevents hidden tab rendering
- Debounced resize prevents layout thrashing
- Proper disposal prevents memory leaks

**Techniques**:
| Optimization | Implementation |
|--------------|----------------|
| Lazy loading | Dynamic `import()` for Three.js |
| Tab visibility | `document.visibilitychange` pauses animation |
| Resize debounce | 100ms debounce on window resize |
| Memory cleanup | `dispose()` method for geometry, textures, renderer |
| Pixel ratio limit | `Math.min(window.devicePixelRatio, 2)` for retina |

### 7. Mobile Touch Support

**Decision**: Use OrbitControls with constrained axes

**Rationale**:
- OrbitControls handles touch events automatically
- Same code works for mouse and touch
- Constraints prevent disorienting interactions (no flip, no zoom)
- Damping provides natural "coasting" feel

**Configuration**:
```javascript
controls.enableDamping = true
controls.dampingFactor = 0.05
controls.enableZoom = false
controls.enablePan = false
controls.minPolarAngle = Math.PI / 4      // Limit vertical
controls.maxPolarAngle = Math.PI / 2 + Math.PI / 12
```

## Resolved Clarifications

All technical unknowns from the specification have been resolved through this research. No NEEDS CLARIFICATION items remain.

## Dependencies Summary

| Dependency | Version | Purpose | Bundle Impact |
|------------|---------|---------|---------------|
| three | ^0.170.0 | 3D rendering | ~150KB gzipped (lazy) |
| OrbitControls | (included) | Mouse/touch rotation | (included in three) |
| GLTFLoader | (included) | Load GLB model | (included in three) |

## Next Steps

Research complete. Proceed to Phase 1:
1. Create data-model.md (minimal - no database changes)
2. Create contracts/ for event API
3. Create quickstart.md for development setup
