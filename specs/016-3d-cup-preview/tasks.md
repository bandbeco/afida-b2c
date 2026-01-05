# Tasks: 3D Cup Preview

**Input**: Design documents from `/specs/016-3d-cup-preview/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/stimulus-events.md, quickstart.md

**Tests**: System tests included as specified in the quickstart.md manual test checklist.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Dependencies & Assets)

**Purpose**: Install Three.js and acquire the 3D model asset

- [ ] T001 Install Three.js dependency: Run `yarn add three@^0.170.0` and verify with `grep "three" package.json`
- [ ] T002 Create models directory: Run `mkdir -p public/models` for 3D asset storage
- [ ] T003 [P] Create test fixture: Add `test/fixtures/files/test_logo.png` (100x100 red square for system tests)

**Asset Acquisition (Manual)**: Per quickstart.md, purchase and convert the TurboSquid model to `public/models/hot_cup_8oz.glb`

---

## Phase 2: Foundational (Shared Infrastructure)

**Purpose**: Create the CupPreview lib class with scene setup before any user story features

**CRITICAL**: User story implementation depends on this phase completing first

- [ ] T004 Create `app/frontend/javascript/lib/cup_preview.js` with CupPreview class skeleton:
  - Export CupPreview class
  - Add static `isWebGLSupported()` method (per research.md pattern)
  - Add constructor accepting `{ canvas, cupColor }` options
  - Add instance properties: scene, camera, renderer, controls, cup, isInitialized, isDisposed
  - Import from 'three' and 'three/examples/jsm/controls/OrbitControls.js' and 'three/examples/jsm/loaders/GLTFLoader.js'

- [ ] T005 Implement `init()` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Create THREE.Scene with ambient light (0xffffff, 0.8) and directional light (0xffffff, 0.5)
  - Create THREE.PerspectiveCamera (45 fov, aspect from canvas, near 0.1, far 1000)
  - Create THREE.WebGLRenderer with canvas, antialias: true, alpha: true
  - Set renderer pixel ratio to `Math.min(window.devicePixelRatio, 2)`
  - Set initial camera position (0, 2, 5)
  - Set isInitialized = true

- [ ] T006 Implement `loadModel()` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Use GLTFLoader to load `/models/hot_cup_8oz.glb`
  - Store loaded model in `this.cup`
  - Add model to scene
  - Return Promise for async loading
  - Center model in scene after loading

- [ ] T007 Implement `setupControls()` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Create OrbitControls attached to camera and renderer.domElement
  - Configure per research.md: enableDamping=true, dampingFactor=0.05
  - Disable zoom (enableZoom=false) and pan (enablePan=false)
  - Set polar angle constraints: minPolarAngle=Math.PI/4, maxPolarAngle=Math.PI/2 + Math.PI/12
  - Store controls reference for later access

- [ ] T008 Implement `animate()` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Use requestAnimationFrame loop
  - Update controls (for damping)
  - Render scene with camera
  - Check isDisposed flag to stop loop

- [ ] T009 Implement `dispose()` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Set isDisposed = true
  - Dispose renderer
  - Dispose all geometries and materials in scene
  - Clean up controls
  - Set all references to null

**Checkpoint**: CupPreview lib can load a 3D cup and render it statically. No texture or auto-rotation yet.

---

## Phase 3: User Story 1 - View Design on Cup in Real-Time (Priority: P1)

**Goal**: Customer uploads PNG/JPG and sees their design on an interactive 3D cup

**Independent Test**: Upload a PNG image on the branded configurator and verify 3D cup appears with design texture

### Implementation for User Story 1

- [ ] T010 [US1] Implement `applyTexture(file)` method in `app/frontend/javascript/lib/cup_preview.js`:
  - Accept File object parameter
  - Use FileReader to read file as data URL
  - Create THREE.TextureLoader and load the data URL
  - Apply texture to cup mesh material
  - Return Promise resolving when texture applied

- [ ] T011 [US1] Create `app/frontend/javascript/controllers/cup_preview_controller.js` Stimulus controller:
  - Define static targets: ['canvas', 'staticImage', 'previewMessage']
  - Define static values: { cupColor: { type: String, default: 'kraft' } }
  - Add connect() method that checks WebGL support
  - Add disconnect() method that calls dispose on CupPreview instance

- [ ] T012 [US1] Implement `showPreview(event)` action in `app/frontend/javascript/controllers/cup_preview_controller.js`:
  - Extract file from event.detail.file
  - Validate file.type is 'image/png' or 'image/jpeg'
  - Lazy import CupPreview from '../lib/cup_preview.js'
  - Initialize CupPreview with canvas target and cupColor value
  - Call init(), loadModel(), applyTexture(file) in sequence
  - Fade out staticImage target, fade in canvas target

- [ ] T013 [US1] Modify `app/frontend/javascript/controllers/branded_configurator_controller.js`:
  - In `handleDesignUpload()` method (around line 380), add: `this.dispatch("designUploaded", { detail: { file } })`
  - Dispatch after successful file validation and before preview display

- [ ] T014 [US1] Register cup-preview controller in `app/frontend/entrypoints/application.js`:
  - Add to lazyControllers object: `"cup-preview": () => import("../javascript/controllers/cup_preview_controller")`

- [ ] T015 [US1] Modify `app/views/branded_products/_branded_configurator.html.erb`:
  - Wrap the existing static product image figure with cup-preview controller div
  - Add data-controller="cup-preview" to wrapper
  - Add data-cup-preview-target="staticImage" to the figure element
  - Add canvas element with data-cup-preview-target="canvas" and class="hidden"
  - Add data-action="branded-configurator:designUploaded->cup-preview#showPreview"
  - Set data-cup-preview-cup-color-value based on product (kraft or white)

- [ ] T016 [US1] Implement auto-rotation in `app/frontend/javascript/lib/cup_preview.js`:
  - Add autoRotate property (default true)
  - Add autoRotateSpeed property (default 0.005 radians/frame for ~20s rotation)
  - In animate() loop, when autoRotate is true, rotate cup.rotation.y += autoRotateSpeed

- [ ] T017 [US1] Implement drag-to-rotate in `app/frontend/javascript/lib/cup_preview.js`:
  - OrbitControls already provides this via mouse/touch events
  - Ensure controls.autoRotate = false (we handle our own auto-rotation)
  - Connect 'start' event on controls to pause autoRotate
  - Test that dragging rotates the cup in expected direction

- [ ] T018 [US1] Add CSS transitions for preview switch in `app/views/branded_products/_branded_configurator.html.erb` or controller:
  - Static image fades out (opacity 0, transition 300ms)
  - Canvas fades in (opacity 1, transition 300ms)
  - Use CSS classes or inline styles toggled by controller

**Checkpoint**: US1 complete - Customer can upload PNG/JPG and see interactive 3D cup with their design. Auto-rotates and can be dragged.

---

## Phase 4: User Story 2 - Graceful Fallback for Unsupported Files (Priority: P2)

**Goal**: PDF/AI uploads show helpful message instead of 3D preview

**Independent Test**: Upload a PDF file and verify message "Preview available for JPG/PNG files" appears

### Implementation for User Story 2

- [ ] T019 [US2] Add `showMessage(text)` method to `app/frontend/javascript/controllers/cup_preview_controller.js`:
  - Show previewMessage target with provided text
  - Ensure staticImage remains visible (no transition)
  - Hide canvas if it was visible

- [ ] T020 [US2] Update `showPreview(event)` in `app/frontend/javascript/controllers/cup_preview_controller.js`:
  - Check file.type before initializing 3D preview
  - If not 'image/png' or 'image/jpeg', call showMessage("Preview available for JPG/PNG files")
  - Return early without initializing CupPreview

- [ ] T021 [US2] Style the preview message element in view:
  - Add p element with data-cup-preview-target="previewMessage" and class="hidden text-center text-gray-500 py-4"
  - Positioned within the preview container area

**Checkpoint**: US2 complete - PDF/AI uploads show helpful message, static photo remains visible

---

## Phase 5: User Story 3 - Auto-Resume After Interaction (Priority: P3)

**Goal**: Auto-rotation resumes 3 seconds after customer stops interacting

**Independent Test**: Drag cup to rotate, release, wait 3 seconds, verify auto-rotation resumes

### Implementation for User Story 3

- [ ] T022 [US3] Add interaction timeout handling to `app/frontend/javascript/lib/cup_preview.js`:
  - Add resumeTimeout property (null initially)
  - Add RESUME_DELAY constant (3000 ms)
  - On controls 'start' event: set autoRotate = false, clear any existing resumeTimeout
  - On controls 'end' event: set resumeTimeout = setTimeout to set autoRotate = true after RESUME_DELAY

- [ ] T023 [US3] Ensure timeout is cleared on dispose in `app/frontend/javascript/lib/cup_preview.js`:
  - In dispose() method, clearTimeout(this.resumeTimeout) before cleanup

**Checkpoint**: US3 complete - Auto-rotation pauses on interaction, resumes after 3 second delay

---

## Phase 6: User Story 4 - Transparent Logo Handling (Priority: P3)

**Goal**: PNG transparency composites onto cup base color (kraft or white)

**Independent Test**: Upload PNG with transparent background, verify transparent areas show cup color

### Implementation for User Story 4

- [ ] T024 [US4] Implement transparency compositing in `applyTexture()` method of `app/frontend/javascript/lib/cup_preview.js`:
  - After loading image, create offscreen canvas
  - Get 2d context, fill with cupColor (kraft: '#a67c52', white: '#ffffff')
  - Draw uploaded image on top (transparency shows background)
  - Create THREE.CanvasTexture from composite canvas
  - Apply composite texture to cup material instead of raw image texture

- [ ] T025 [US4] Add color constants to `app/frontend/javascript/lib/cup_preview.js`:
  - Add CUP_COLORS object: { kraft: '#a67c52', white: '#ffffff' }
  - Use cupColor value to select background color for compositing

**Checkpoint**: US4 complete - Transparent PNGs render with correct background color based on cup variant

---

## Phase 7: Edge Cases & Polish

**Purpose**: Handle edge cases from spec.md and add robustness

- [ ] T026 [P] Implement WebGL fallback in `app/frontend/javascript/controllers/cup_preview_controller.js`:
  - In connect(), check CupPreview.isWebGLSupported()
  - If false, set this.webglSupported = false
  - In showPreview(), if !webglSupported, return early without initializing (silent fallback per FR-009)

- [ ] T027 [P] Implement reset handling in `app/frontend/javascript/controllers/cup_preview_controller.js`:
  - Add `reset()` action method
  - Dispose CupPreview instance if exists
  - Hide canvas, show staticImage, hide previewMessage
  - Add data-action for branded-configurator:configuratorReset event in view

- [ ] T028 [US1] Add configuratorReset event dispatch to `app/frontend/javascript/controllers/branded_configurator_controller.js`:
  - In resetConfigurator() method, add: `this.dispatch("configuratorReset")`

- [ ] T029 [P] Implement visibility API pause in `app/frontend/javascript/lib/cup_preview.js`:
  - Add document.addEventListener('visibilitychange', handler) in init()
  - When document.hidden, pause animation loop
  - When document visible, resume animation loop
  - Remove listener in dispose()

- [ ] T030 [P] Handle image replacement (new upload while preview loading):
  - In showPreview(), if CupPreview instance exists, dispose it first
  - Create fresh instance for new upload
  - Prevents race conditions with multiple rapid uploads

- [ ] T031 [P] Add responsive canvas sizing in `app/frontend/javascript/lib/cup_preview.js`:
  - Add handleResize() method
  - Update camera aspect ratio and renderer size based on container
  - Debounce resize handler (100ms per research.md)
  - Add/remove window resize listener in init/dispose

- [ ] T032 Create system test `test/system/cup_preview_test.rb`:
  - Test uploading PNG shows 3D canvas (check canvas element visible)
  - Test uploading PDF shows preview message
  - Test reset hides canvas and shows static image
  - Use test_logo.png fixture

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on T001 (Three.js installed) - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion
- **User Story 2 (Phase 4)**: Depends on T011 (controller exists) from US1
- **User Story 3 (Phase 5)**: Depends on T016-T017 (auto-rotation exists) from US1
- **User Story 4 (Phase 6)**: Depends on T010 (applyTexture exists) from US1
- **Polish (Phase 7)**: Can start after US1 minimum, enhances all stories

### Task Dependencies Within Phases

**Phase 2 (Foundational)**:
- T004 → T005 → T006 → T007 → T008 → T009 (sequential - building on lib class)

**Phase 3 (US1)**:
- T010 requires T006 (model loaded to apply texture)
- T011 can start immediately (scaffolds controller)
- T012 requires T010 + T011
- T013 can start immediately (modifies existing file)
- T014 requires T011 (registers controller)
- T015 requires T014 (view references controller)
- T016-T017 require T008 (animation loop)
- T018 requires T015 (view exists)

**Phase 7 (Polish)**:
- T026, T027, T029, T030, T31 are all [P] - can run in parallel
- T028 requires branded_configurator changes from T013
- T032 requires most features complete

### Parallel Opportunities

```bash
# Phase 1 parallel:
Task: T001 (install three.js)
Task: T002 (create models dir)
Task: T003 (create test fixture)

# Phase 3 parallel start:
Task: T011 (create cup_preview_controller.js skeleton)
Task: T013 (modify branded_configurator_controller.js)

# Phase 7 parallel:
Task: T026 (WebGL fallback)
Task: T027 (reset handling)
Task: T029 (visibility API)
Task: T030 (image replacement)
Task: T031 (responsive sizing)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T009)
3. Complete Phase 3: User Story 1 (T010-T018)
4. **STOP and VALIDATE**: Test PNG/JPG upload shows interactive 3D cup
5. Deploy/demo MVP

### Incremental Delivery

1. Setup + Foundational → CupPreview lib ready
2. Add User Story 1 → Test 3D preview → Deploy (MVP!)
3. Add User Story 2 → Test PDF message → Deploy
4. Add User Story 3 → Test auto-resume → Deploy
5. Add User Story 4 → Test transparency → Deploy
6. Add Polish → Full edge case coverage → Final deploy

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story can be tested independently per spec.md
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Manual asset acquisition (3D model) is prerequisite - track separately
