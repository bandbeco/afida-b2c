# Feature Specification: Reorder Schedule Conversion Page Redesign

**Feature Branch**: `001-reorder-schedule-conversion`
**Created**: 2026-01-06
**Status**: Draft
**Input**: User description: "Redesign the Set Up Reorder Schedule page as a conversion-focused page to increase customer LTV. The page should work harder to convince users to take action. 'Pause or cancel anytime' should be front and center to remove unwillingness to commit."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - User Understands Flexibility Before Commitment (Priority: P1)

A customer who has just completed an order lands on the reorder schedule setup page. Before they consider the frequency options, they immediately see that they can cancel anytime, skip deliveries, and edit items before each order. This removes commitment anxiety and makes them willing to explore the feature.

**Why this priority**: Commitment anxiety is the #1 blocker for subscription signups. If users don't feel safe, they won't engage with the rest of the page regardless of how good it is.

**Independent Test**: Can be tested by showing the page to users and measuring whether they scroll past the hero section—if flexibility messaging works, users will engage rather than bounce.

**Acceptance Scenarios**:

1. **Given** a customer arrives on the setup page, **When** the page loads, **Then** they see flexibility messaging ("Cancel anytime", "Skip or pause deliveries", "Edit items before each order") prominently displayed without scrolling.

2. **Given** a customer has commitment concerns, **When** they scan the page, **Then** flexibility reassurance appears in at least two locations (hero badges and below CTA button).

---

### User Story 2 - User Selects Delivery Frequency (Priority: P1)

A customer decides they want to set up automatic delivery. They choose how often they need supplies from clear, easy-to-understand options. The most popular option is highlighted to help with decision-making.

**Why this priority**: Frequency selection is the core functional requirement—without it, the feature doesn't work.

**Independent Test**: Can be tested by confirming user can select a frequency and that selection persists through form submission.

**Acceptance Scenarios**:

1. **Given** a customer is on the setup page, **When** they view the frequency options, **Then** they see 4 choices: Every Week, Every Two Weeks, Every Month, Every 3 Months.

2. **Given** frequency options are displayed, **When** the page loads, **Then** "Every Month" is pre-selected as the default.

3. **Given** frequency options are displayed, **When** the customer views them, **Then** the "Every Month" option shows a "Most popular" indicator.

4. **Given** a customer clicks a frequency option, **When** they make a selection, **Then** the option is visually highlighted and the value is captured for form submission.

---

### User Story 3 - User Reviews Order Summary (Priority: P2)

A customer wants to confirm what they're signing up for before committing. They can see a summary of items and total cost per delivery, with the option to expand for full details.

**Why this priority**: Transparency builds trust, but the summary shouldn't dominate the page since users just completed checkout and know what they ordered.

**Independent Test**: Can be tested by confirming the summary shows accurate item count and total, and that expand/collapse works correctly.

**Acceptance Scenarios**:

1. **Given** a customer is on the setup page, **When** they view the order summary, **Then** they see item count and total per delivery in a compact format.

2. **Given** the order summary is displayed in compact form, **When** the customer clicks to expand, **Then** full line-item details are revealed.

3. **Given** the order summary is expanded, **When** the customer clicks to collapse, **Then** it returns to the compact view.

---

### User Story 4 - User Understands the Process (Priority: P2)

A customer who has never used automatic reordering wants to understand how it works before committing. They see a clear, visual 3-step explanation that reassures them about security and control.

**Why this priority**: Understanding reduces friction and builds confidence, but most users can infer the process—this is supporting content.

**Independent Test**: Can be tested by showing the page and asking users to explain how the process works—high comprehension indicates success.

**Acceptance Scenarios**:

1. **Given** a customer views the page, **When** they see the "How it works" section, **Then** it displays exactly 3 steps: (1) Card saved securely, (2) Reminder email 3 days before, (3) Confirm with one click.

2. **Given** the "How it works" section is displayed, **When** the customer scans it, **Then** each step has a visual indicator (number or icon) and brief text.

---

### User Story 5 - User Completes Setup (Priority: P1)

A customer who is ready to commit clicks the call-to-action button and proceeds to payment setup. The button clearly communicates the action and is supported by final trust messaging.

**Why this priority**: This is the conversion action—the entire page exists to get users to this point.

**Independent Test**: Can be tested by confirming button is clickable, submits the form with correct data, and redirects to payment setup.

**Acceptance Scenarios**:

1. **Given** a customer is ready to set up automatic delivery, **When** they view the CTA, **Then** it reads "Set Up Automatic Delivery" (not payment-focused language).

2. **Given** the CTA button is displayed, **When** the customer views below it, **Then** they see trust messaging including Stripe security mention and "Cancel anytime" reminder.

3. **Given** a customer clicks the CTA, **When** the form submits successfully, **Then** they are redirected to the Stripe payment setup flow with the selected frequency.

---

### Edge Cases

- What happens when the order has only 1 item? The compact summary should show "1 item" (not "1 items").
- What happens when the order total is very high (e.g., £5,000+)? The summary should display correctly without layout breaking.
- What happens when JavaScript is disabled? The expand/collapse summary should fall back to showing full details.
- How does the page handle users who already have an active reorder schedule for this order? They should be redirected or shown appropriate messaging.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Page MUST display flexibility messaging ("Cancel anytime", "Skip or pause deliveries", "Edit items before each order") prominently in the hero section without requiring scroll.
- **FR-002**: Page MUST display 4 frequency options (Every Week, Every Two Weeks, Every Month, Every 3 Months) in a 2x2 grid layout.
- **FR-003**: System MUST pre-select "Every Month" as the default frequency.
- **FR-004**: Page MUST display a "Most popular" indicator on the "Every Month" option.
- **FR-005**: Page MUST display a compact order summary showing item count and total per delivery.
- **FR-006**: Users MUST be able to expand the order summary to see full line-item details.
- **FR-007**: Page MUST display a 3-step "How it works" section above the CTA button.
- **FR-008**: CTA button MUST read "Set Up Automatic Delivery".
- **FR-009**: Page MUST display trust messaging below the CTA including Stripe security mention and flexibility reminder.
- **FR-010**: Form submission MUST include selected frequency and order ID.
- **FR-011**: Page structure MUST accommodate a future discount/incentive banner in the frequency section without requiring layout changes.

### Key Entities

- **Order**: The completed order that the user wants to set up for automatic redelivery. Key attributes: items, total amount.
- **Reorder Schedule**: The recurring delivery configuration being created. Key attributes: frequency, associated order items.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Conversion rate (page visitors who complete setup) increases by at least 20% compared to current baseline.
- **SC-002**: Time to complete setup (from page load to CTA click) decreases or stays the same—improved messaging should not add friction.
- **SC-003**: Bounce rate (users who leave without scrolling past hero) decreases by at least 15%.
- **SC-004**: 90% of users can correctly explain the "cancel anytime" policy after viewing the page (validated through user testing).
- **SC-005**: Support tickets asking "how do I cancel my subscription?" do not increase after launch.

## Assumptions

- The current Stripe payment setup flow will remain unchanged; this redesign only affects the pre-payment setup page.
- No discount or incentive will be offered at launch, but the design must accommodate adding one later.
- The frequency options will remain the same (no changes to available intervals).
- Users arrive at this page from the order confirmation page, so they have context about what they just purchased.
- Mobile responsiveness is required; the design must work on screens 320px and wider.
