# Data Model: 3D Cup Preview

**Feature**: 016-3d-cup-preview
**Date**: 2025-12-21

## Overview

This feature requires **no database changes**. All data is client-side:

- **Uploaded image**: Held in browser memory via FileReader
- **3D model**: Static file served from `public/models/`
- **Preview state**: Managed by Stimulus controller instance variables

## Entities (Client-Side Only)

### CupPreview (JavaScript Class)

A client-side object managing the 3D scene lifecycle.

| Property | Type | Description |
|----------|------|-------------|
| canvas | HTMLCanvasElement | The rendering target |
| cupColor | String | Base color: "kraft" or "white" |
| scene | THREE.Scene | The 3D scene container |
| camera | THREE.PerspectiveCamera | Viewing camera |
| renderer | THREE.WebGLRenderer | WebGL renderer |
| controls | OrbitControls | User interaction handler |
| cup | THREE.Object3D | The loaded cup model |
| autoRotate | Boolean | Whether auto-rotation is active |
| isInitialized | Boolean | Whether scene is ready |
| isDisposed | Boolean | Whether resources are cleaned up |

### Design Texture (Transient)

The uploaded image converted to a Three.js texture.

| Property | Type | Description |
|----------|------|-------------|
| file | File | Original uploaded file |
| dataUrl | String | Base64 data URL from FileReader |
| texture | THREE.Texture | The applied texture |
| hasTransparency | Boolean | Whether PNG has alpha channel |

## State Transitions

```
[Static Photo] ---(upload PNG/JPG)---> [Initializing]
[Initializing] ---(scene ready)---> [3D Preview Active]
[3D Preview Active] ---(user drag)---> [Manual Control]
[Manual Control] ---(3s idle)---> [3D Preview Active]
[3D Preview Active] ---(reset)---> [Static Photo]
[Any State] ---(tab hidden)---> [Paused]
[Paused] ---(tab visible)---> [Previous State]
```

## Database Impact

**None**. This feature is entirely client-side.

Future consideration: If we want to persist the last-viewed angle or track 3D preview usage analytics, that would require new database entities. Not in current scope.
