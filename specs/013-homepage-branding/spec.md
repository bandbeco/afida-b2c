# Feature Specification: Homepage Branding Section Redesign

**Feature Branch**: `013-homepage-branding`
**Created**: 2025-12-14
**Status**: Draft
**Input**: User description: "Redesign homepage branding section with masonry photo collage"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visual Discovery of Branding Service (Priority: P1)

A visitor browsing the homepage scrolls down and encounters a visually striking section showcasing real customer-branded products. The photo collage immediately captures attention and communicates "this is what your brand could look like on our products."

**Why this priority**: The photo collage is the primary visual hook that differentiates this section from generic marketing. It provides social proof and sparks imagination about what's possible.

**Independent Test**: Can be fully tested by viewing the homepage and verifying the collage displays correctly, delivers immediate visual impact, and conveys the branding service concept without needing to read any text.

**Acceptance Scenarios**:

1. **Given** a visitor on the homepage, **When** they scroll to the branding section, **Then** they see a masonry grid of 6 customer photos displaying branded cups
2. **Given** a visitor viewing the collage on desktop, **When** they see the photos, **Then** the photos are arranged in a visually interesting masonry layout with varied sizes
3. **Given** a visitor viewing the collage on mobile, **When** they see the photos, **Then** the layout adapts to 2 columns while maintaining visual appeal

---

### User Story 2 - Understanding the Value Proposition (Priority: P2)

After being visually engaged by the photo collage, visitors see a clear headline and trust badges that communicate what the branding service offers and why it's compelling: no setup fees, UK production, fast turnaround, and low minimums.

**Why this priority**: Visual interest alone doesn't convert—visitors need to quickly understand the offer's key benefits to decide if they want to learn more.

**Independent Test**: Can be tested by showing the section to users and asking them to explain what the branding service offers. Users should be able to articulate key benefits within 5 seconds of reading.

**Acceptance Scenarios**:

1. **Given** a visitor viewing the branding section, **When** they look below the collage, **Then** they see the headline "Your Brand. Your Cup." prominently displayed
2. **Given** a visitor reading the section, **When** they scan the trust badges, **Then** they see 4 specific value props: UK production, 1,000 minimum units, 20-day turnaround, and £0 setup fees
3. **Given** a visitor on any device, **When** they view the trust badges, **Then** each badge clearly displays an icon, a number/value, and a label

---

### User Story 3 - Taking Action (Priority: P3)

A visitor who is interested in the branding service can easily take action by clicking a prominent call-to-action button that leads them to the branding configurator or product page.

**Why this priority**: The CTA is the conversion point—but without visual engagement (P1) and value understanding (P2), visitors won't reach this stage.

**Independent Test**: Can be tested by clicking the CTA button and verifying it navigates to the correct destination (branded products page).

**Acceptance Scenarios**:

1. **Given** a visitor interested in branding, **When** they click the "Start Designing" button, **Then** they are navigated to the branded products page
2. **Given** a visitor on the branding section, **When** they look for a way to proceed, **Then** the CTA button is clearly visible and prominently styled
3. **Given** a visitor on mobile, **When** they want to take action, **Then** the CTA button is easily tappable and above the fold after scrolling through the collage

---

### Edge Cases

- What happens when images fail to load? Fallback background color or placeholder should maintain visual appeal
- How does the collage behave on very wide screens (>1920px)? Layout should remain centered and not stretch awkwardly
- How does the section look on very narrow screens (<320px)? Content should remain readable and collage should still function

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Section MUST display 6 customer photos in a masonry grid layout
- **FR-002**: Photos MUST be arranged with varied sizes (some spanning multiple rows) to create visual interest
- **FR-003**: Section MUST display the headline "Your Brand. Your Cup." with "Your Cup." in gradient text (green tones)
- **FR-004**: Section MUST display 4 trust badges showing: UK production, 1,000 minimum units, 20-day turnaround, £0 setup fees
- **FR-005**: Each trust badge MUST include an icon, a prominent number/value, and a descriptive label
- **FR-006**: Section MUST include a primary CTA button labeled "Start Designing" linking to the branded products page
- **FR-007**: Collage MUST display in 3 columns on desktop and 2 columns on mobile/tablet
- **FR-008**: Trust badges MUST display in a horizontal row (4 across) on desktop and 2x2 grid on mobile
- **FR-009**: Section MUST maintain the pink background color (#ffb7c5) consistent with Afida's branding page
- **FR-010**: Photos MUST have neobrutalist styling (black borders, rounded corners, hover effects)

### Key Entities

- **Customer Photo**: A photograph of a real customer's branded product (cup), sourced from existing branding gallery assets
- **Trust Badge**: A visual element combining an icon, a quantitative value, and a label to communicate a specific benefit

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Section displays correctly on all tested screen sizes (mobile 375px, tablet 768px, desktop 1280px, wide 1920px)
- **SC-002**: All 6 photos load and display within the masonry layout without overlap issues or broken images
- **SC-003**: CTA button click successfully navigates to the branded products page
- **SC-004**: Page load time with the new section remains under 3 seconds on standard connection
- **SC-005**: Section passes accessibility checks (images have alt text, adequate color contrast, keyboard navigable CTA)
- **SC-006**: User testing confirms visitors can identify the branding service offering within 5 seconds of viewing the section

## Assumptions

- The 6 customer photos from the existing branding page gallery (DSC_6621.webp through DSC_7239.webp) are approved for use on the homepage
- The pink background color (#ffb7c5) is consistent with brand guidelines and approved for this section
- The neobrutalist design style (black borders, box shadows) is consistent with the site's overall design language
- No additional photography or assets are required—existing branding gallery images are sufficient
- The branded products page (/branded_products) already exists and is the correct destination for the CTA

## Scope Boundaries

**In Scope**:
- Redesigning the `_branding.html.erb` partial
- Implementing masonry photo collage layout
- Adding headline, trust badges, and CTA
- Responsive behavior for mobile, tablet, and desktop

**Out of Scope**:
- Changes to the dedicated branding page (`branding.html.erb`)
- New photography or photo editing
- A/B testing infrastructure
- Analytics tracking beyond existing site implementation
- Changes to the branded products configurator or destination page
