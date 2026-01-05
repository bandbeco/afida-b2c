# Quickstart: 3D Cup Preview Development

**Feature**: 016-3d-cup-preview
**Date**: 2025-12-21

## Prerequisites

### 1. Install Three.js

```bash
yarn add three@^0.170.0
```

Verify installation:
```bash
grep "three" package.json
# Expected: "three": "^0.170.0"
```

### 2. Acquire 3D Model

1. **Purchase** the TurboSquid model ($29):
   - URL: https://www.turbosquid.com/3d-models/coffee-cup-empty-8oz-takeout-2-1056690
   - Download OBJ format

2. **Convert to GLB** using Blender:
   ```bash
   # Install Blender if needed (macOS)
   brew install --cask blender
   ```

   In Blender:
   - File > Import > Wavefront (.obj) - select downloaded model
   - Verify UV mapping looks correct in UV Editor
   - File > Export > glTF 2.0 (.glb/.gltf)
   - Settings: Format = glTF Binary (.glb), Include = Selected Objects
   - Save to: `public/models/hot_cup_8oz.glb`

3. **Create directory and verify**:
   ```bash
   mkdir -p public/models
   ls -la public/models/hot_cup_8oz.glb
   # Expected: file exists, ~2-5MB
   ```

### 3. Create Test Fixture

Create a test logo image for system tests:

```bash
# Option A: Use ImageMagick
convert -size 100x100 xc:red test/fixtures/files/test_logo.png

# Option B: Copy any small PNG file
cp path/to/any/logo.png test/fixtures/files/test_logo.png
```

## Development Workflow

### Start Development Server

```bash
bin/dev
```

This starts:
- Rails server on port 3000
- Vite dev server with hot reload

### Navigate to Configurator

1. Sign in as a test user
2. Browse to any branded product (e.g., `/products/branded-double-wall-cup`)
3. Complete Steps 1-3 (size, quantity, skip lids)
4. Upload a PNG or JPG in Step 4

### Verify 3D Preview

After implementing, you should see:
- Static product photo fades out
- 3D cup canvas fades in
- Cup rotates automatically
- Drag to manually rotate
- Auto-rotation resumes after 3 seconds

### Browser DevTools

Check for errors:
```javascript
// In console, verify WebGL support:
!!document.createElement('canvas').getContext('webgl')
// Expected: true
```

## Testing

### Run System Tests

```bash
# All system tests
rails test:system

# Just 3D preview tests
rails test test/system/cup_preview_test.rb
```

### Manual Test Checklist

| Test | Expected Result |
|------|-----------------|
| Upload PNG | 3D preview appears |
| Upload JPG | 3D preview appears |
| Upload PDF | "Preview available for JPG/PNG" message |
| Drag cup | Cup rotates in drag direction |
| Stop dragging | Auto-rotation resumes after 3s |
| Reset configurator | Static image returns |
| Disable WebGL (browser flag) | Static image stays, no error |

### Browser Testing Matrix

Test on:
- Chrome (desktop + mobile)
- Safari (desktop + iOS)
- Firefox (desktop)
- Edge (desktop)

## File Locations

| File | Purpose |
|------|---------|
| `app/frontend/javascript/lib/cup_preview.js` | Three.js scene logic |
| `app/frontend/javascript/controllers/cup_preview_controller.js` | Stimulus controller |
| `app/frontend/javascript/controllers/branded_configurator_controller.js` | Modified: event dispatch |
| `app/frontend/entrypoints/application.js` | Modified: register controller |
| `app/views/branded_products/_branded_configurator.html.erb` | Modified: add canvas |
| `public/models/hot_cup_8oz.glb` | 3D cup model |
| `test/system/cup_preview_test.rb` | System tests |
| `test/fixtures/files/test_logo.png` | Test fixture |

## Common Issues

### "Cannot find module 'three'"

Run `yarn add three@^0.170.0` and restart `bin/dev`.

### Model doesn't load (404)

Verify file exists at `public/models/hot_cup_8oz.glb` and is accessible at `http://localhost:3000/models/hot_cup_8oz.glb`.

### Cup appears black

Check UV mapping in Blender before export. The model must have proper UV coordinates.

### Preview doesn't appear on upload

1. Check browser console for errors
2. Verify `cup-preview` controller is registered in `application.js`
3. Verify event dispatch in `branded_configurator_controller.js`
4. Verify `data-action` attribute in view

### Touch rotation doesn't work on mobile

Ensure OrbitControls is imported from `three/examples/jsm/controls/OrbitControls.js`, not the legacy `three/examples/js/` path.
