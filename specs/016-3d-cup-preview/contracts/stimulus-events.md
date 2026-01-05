# Stimulus Events Contract: 3D Cup Preview

**Feature**: 016-3d-cup-preview
**Date**: 2025-12-21

## Overview

This feature uses Stimulus custom events for controller-to-controller communication. No HTTP APIs are introduced.

## Event: `branded-configurator:designUploaded`

**Emitter**: `branded_configurator_controller.js`
**Listener**: `cup_preview_controller.js`
**Trigger**: When customer successfully uploads a design file

### Event Detail Schema

```typescript
interface DesignUploadedEvent {
  detail: {
    file: File  // The uploaded File object
  }
}
```

### Example Dispatch

```javascript
// In branded_configurator_controller.js
handleDesignUpload(event) {
  const file = event.target.files[0]
  // ... validation ...

  this.dispatch("designUploaded", {
    detail: { file }
  })
}
```

### Example Listener (HTML)

```html
<div data-controller="cup-preview"
     data-action="branded-configurator:designUploaded->cup-preview#showPreview">
```

### Handler Signature

```javascript
// In cup_preview_controller.js
showPreview(event) {
  const { file } = event.detail
  // file.type: "image/png" | "image/jpeg" | "application/pdf" | etc.
  // file.name: "logo.png"
  // file.size: 12345 (bytes)
}
```

---

## Event: `branded-configurator:configuratorReset`

**Emitter**: `branded_configurator_controller.js`
**Listener**: `cup_preview_controller.js`
**Trigger**: When customer resets the configurator (after adding to cart or manually)

### Event Detail Schema

```typescript
interface ConfiguratorResetEvent {
  detail: {}  // No payload
}
```

### Example Dispatch

```javascript
// In branded_configurator_controller.js
resetConfigurator() {
  // ... reset logic ...

  this.dispatch("configuratorReset")
}
```

### Example Listener (HTML)

```html
<div data-controller="cup-preview"
     data-action="branded-configurator:configuratorReset->cup-preview#reset">
```

### Handler Signature

```javascript
// In cup_preview_controller.js
reset() {
  // Hide canvas, show static image, dispose 3D resources
}
```

---

## Controller Values Contract

### cup_preview_controller.js Values

```javascript
static values = {
  cupColor: { type: String, default: "kraft" }  // "kraft" | "white"
}
```

### HTML Configuration

```html
<div data-controller="cup-preview"
     data-cup-preview-cup-color-value="kraft">
```

---

## Controller Targets Contract

### cup_preview_controller.js Targets

| Target | Element | Purpose |
|--------|---------|---------|
| canvas | `<canvas>` | WebGL rendering surface |
| staticImage | `<figure>` or `<div>` | Static product photo container |
| previewMessage | `<p>` | Message for unsupported file types |

### HTML Structure

```html
<div data-controller="cup-preview" ...>
  <figure data-cup-preview-target="staticImage">
    <img src="..." alt="...">
  </figure>

  <canvas data-cup-preview-target="canvas" class="hidden ..."></canvas>

  <p data-cup-preview-target="previewMessage" class="hidden ..."></p>
</div>
```

---

## File Type Support Matrix

| File Type | MIME Type | 3D Preview | Behavior |
|-----------|-----------|------------|----------|
| PNG | image/png | Yes | Show 3D preview |
| JPG/JPEG | image/jpeg | Yes | Show 3D preview |
| PDF | application/pdf | No | Show message |
| AI | application/postscript | No | Show message |
| Other | * | No | Show message |
