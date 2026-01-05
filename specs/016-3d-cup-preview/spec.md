# Feature Specification: 3D Cup Preview

**Feature Branch**: `016-3d-cup-preview`
**Created**: 2025-12-21
**Status**: Draft
**Input**: User description: "Add interactive 3D preview to branded product configurator showing customers their uploaded design wrapped onto a cup in real-time"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Design on Cup in Real-Time (Priority: P1)

A customer ordering branded cups wants to see their logo or design wrapped around a 3D cup immediately after uploading, giving them confidence their design will look good before placing an order.

**Why this priority**: This is the core value proposition - instant visual feedback differentiates the service from competitors who only show static mockups or require manual design proofs.

**Independent Test**: Can be fully tested by uploading a PNG/JPG image and observing a 3D cup rendering with the design visible. Delivers immediate customer confidence and reduces design-related support queries.

**Acceptance Scenarios**:

1. **Given** a customer is on the branded product configurator with size and quantity selected, **When** they upload a PNG image, **Then** the static product photo transitions to an interactive 3D cup displaying their uploaded design
2. **Given** the 3D preview is displaying, **When** the customer views the page without interaction, **Then** the cup automatically rotates slowly to showcase all angles of the design
3. **Given** the 3D preview is displaying, **When** the customer drags/swipes on the cup, **Then** the cup rotates in the direction of drag, allowing manual inspection of any angle

---

### User Story 2 - Graceful Fallback for Unsupported Files (Priority: P2)

A customer uploading a PDF or AI file (supported for printing but not for 3D preview) should understand why they can't see a preview and still complete their order without confusion.

**Why this priority**: PDF/AI files are common for print designs. Customers shouldn't feel something is broken - they need clear communication about preview limitations.

**Independent Test**: Can be tested by uploading a PDF file and verifying a helpful message appears while the static product photo remains visible.

**Acceptance Scenarios**:

1. **Given** a customer is on the configurator, **When** they upload a PDF file, **Then** a message displays "Preview available for JPG/PNG files" and the static product photo remains visible
2. **Given** a customer is on the configurator, **When** they upload an AI file, **Then** the same helpful message displays and the configurator remains fully functional

---

### User Story 3 - Auto-Resume After Interaction (Priority: P3)

A customer who manually rotates the cup to inspect their design should see the auto-rotation resume after they stop interacting, keeping the preview engaging and dynamic.

**Why this priority**: Enhances the premium feel of the experience. Without this, the cup would freeze at whatever angle the customer left it.

**Independent Test**: Can be tested by manually rotating the cup, releasing, and observing auto-rotation resumes after a brief pause.

**Acceptance Scenarios**:

1. **Given** the cup is auto-rotating, **When** the customer clicks/touches and drags, **Then** auto-rotation stops immediately and the cup follows user control
2. **Given** the customer has stopped interacting with the cup, **When** 3 seconds pass without interaction, **Then** auto-rotation smoothly resumes

---

### User Story 4 - Transparent Logo Handling (Priority: P3)

A customer uploading a logo with transparent background (PNG) should see it composited onto the cup's natural color (kraft brown or white), rather than seeing the transparency as a black or missing area.

**Why this priority**: Many business logos are PNG files with transparency. Proper handling prevents confusion about how the final print will look.

**Independent Test**: Can be tested by uploading a PNG with transparency and verifying the logo appears on the appropriate cup base color.

**Acceptance Scenarios**:

1. **Given** a customer uploads a PNG logo with transparent areas, **When** the 3D preview renders, **Then** transparent areas show the cup's base color (kraft brown for hot cups)
2. **Given** the product is a white cup variant, **When** a transparent PNG is uploaded, **Then** transparent areas show white instead of kraft brown

---

### Edge Cases

- What happens when the customer's browser doesn't support 3D graphics (WebGL)?
  - The static product photo remains visible; no error message shown (graceful degradation)
- What happens when the customer uploads an image while a previous preview is still loading?
  - The new image replaces the previous one; no queue or waiting
- What happens when the customer resets the configurator after viewing a 3D preview?
  - The 3D preview is hidden and the static product photo reappears
- What happens when the browser tab is hidden (customer switches tabs)?
  - The 3D animation pauses to save battery/CPU; resumes when tab becomes visible

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display an interactive 3D cup when the customer uploads a PNG or JPG image
- **FR-002**: System MUST apply the uploaded image as a texture wrapped around the cup surface
- **FR-003**: System MUST transition smoothly from static photo to 3D preview (visual fade effect)
- **FR-004**: System MUST auto-rotate the cup at a slow, comfortable viewing speed (~20 seconds per rotation)
- **FR-005**: System MUST allow customers to manually rotate the cup by dragging (mouse) or swiping (touch)
- **FR-006**: System MUST pause auto-rotation when customer interacts with the cup
- **FR-007**: System MUST resume auto-rotation 3 seconds after the last customer interaction
- **FR-008**: System MUST display a helpful message for PDF/AI uploads indicating preview is not available for those formats
- **FR-009**: System MUST silently fall back to static photo if WebGL is not supported (no error message)
- **FR-010**: System MUST composite transparent PNG images onto the cup's base color
- **FR-011**: System MUST reset to static photo when the configurator form is reset
- **FR-012**: System MUST pause 3D rendering when browser tab is hidden to conserve resources
- **FR-013**: System MUST limit vertical rotation (tilt) to prevent customers from flipping the cup upside down
- **FR-014**: System MUST maintain responsive sizing (3D preview fits container on all screen sizes)

### Key Entities

- **3D Cup Model**: A web-optimized 3D representation of the hot cup product, with UV mapping for texture application
- **Design Texture**: The customer's uploaded image file converted to a format suitable for 3D rendering
- **Preview Container**: The left panel of the configurator that switches between static photo and 3D canvas

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Customers can see their design on a 3D cup within 3 seconds of uploading a PNG/JPG image
- **SC-002**: The 3D preview works correctly on 95%+ of modern browsers (Chrome, Firefox, Safari, Edge on desktop and mobile)
- **SC-003**: Customers can rotate the cup smoothly at 30+ frames per second on standard devices
- **SC-004**: The feature adds less than 200KB to initial page load (lazy-loaded only when needed)
- **SC-005**: No customer-facing errors appear when using unsupported file types or older browsers
- **SC-006**: Mobile users can touch-drag to rotate just as easily as desktop users can mouse-drag

## Assumptions

- Hot cups (8oz) are the initial scope; other sizes and product types will be added later
- The 3D model will be purchased from a commercial asset marketplace (pre-existing design decision)
- Standard web browser with JavaScript enabled is required (progressive enhancement for non-JS users not in scope)
- Image processing (texture application) happens client-side; no server-side image manipulation required
- Cup base color is determined by product type (kraft for most hot cups, white for specific variants)
