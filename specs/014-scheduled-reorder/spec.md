# Feature Specification: Scheduled Reorder with Review

**Feature Branch**: `014-scheduled-reorder`
**Created**: 2025-12-16
**Status**: Draft
**Input**: User description: "Scheduled Reorder with Review - customers set up reorder schedules from past orders, receive reminder emails before delivery, one-click confirm or edit-then-confirm flow"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set Up Reorder Schedule from Past Order (Priority: P1)

A logged-in customer who regularly orders the same products wants to automate their repeat ordering process. After placing an order, they set up a schedule to receive reminders before their next delivery, so they don't have to remember to reorder manually.

**Why this priority**: Core value proposition - enables customers to set up automated reordering, which drives retention and reduces friction for repeat purchases. Without this, the feature has no entry point.

**Independent Test**: Log in, view a past order, click "Schedule this order", select frequency, save payment method, verify schedule is created with correct items and next delivery date.

**Acceptance Scenarios**:

1. **Given** I am logged in and viewing my order confirmation page, **When** I click "Set up reorder schedule", **Then** I see a form to select delivery frequency
2. **Given** I have selected a frequency (e.g., monthly), **When** I save my payment method and confirm, **Then** a reorder schedule is created with all items from my order
3. **Given** I have created a reorder schedule, **When** I visit "My Reorder Schedules", **Then** I see the schedule with correct frequency, next delivery date, and items
4. **Given** I am viewing a past order in my order history, **When** I click "Schedule this order", **Then** I can set up a reorder schedule from that order's items

---

### User Story 2 - One-Click Order Confirmation from Email (Priority: P2)

A customer with an active reorder schedule wants to confirm their upcoming order with minimal effort. They receive an email reminder before their scheduled delivery date and can confirm with one click, charging their saved payment method.

**Why this priority**: Delivers the primary value of the feature - effortless repeat ordering for customers who want "autopilot" convenience. This is the recurring experience after initial setup.

**Independent Test**: With an active schedule approaching delivery date, verify email is received with order summary, click confirm button, verify order is created and charged to saved payment method.

**Acceptance Scenarios**:

1. **Given** I have an active reorder schedule, **When** my next delivery date is 3 days away, **Then** I receive an email with my order summary and confirm/edit buttons
2. **Given** I received a reorder reminder email, **When** I click "Confirm Order", **Then** my saved payment method is charged and the order is placed
3. **Given** my order was confirmed via email, **When** I check my order history, **Then** I see the new order linked to my reorder schedule
4. **Given** my order was confirmed, **When** I receive confirmation, **Then** my schedule's next delivery date is advanced by the frequency interval

---

### User Story 3 - Edit Order Before Confirmation (Priority: P3)

A customer wants to adjust their scheduled order before confirming - adding items, removing items, or changing quantities. They click "Edit Order" from the email, make changes, and then confirm.

**Why this priority**: Supports the "tweaker" customer segment who need flexibility. Critical for customer satisfaction but secondary to the core confirm flow.

**Independent Test**: Receive reminder email, click "Edit Order", modify quantities and add/remove items, confirm the edited order, verify order contains the changes.

**Acceptance Scenarios**:

1. **Given** I received a reorder reminder email, **When** I click "Edit Order", **Then** I see a page showing my scheduled items with ability to modify
2. **Given** I am editing my pending order, **When** I change a quantity, **Then** the subtotal updates accordingly
3. **Given** I am editing my pending order, **When** I add a new product, **Then** it appears in my order with the current price
4. **Given** I am editing my pending order, **When** I remove an item, **Then** it is no longer in my order
5. **Given** I have finished editing, **When** I click "Place Order", **Then** the order is confirmed with my modifications

---

### User Story 4 - Manage Reorder Schedule (Priority: P4)

A customer wants to manage their reorder schedule - pause deliveries during a slow period, change frequency, update items permanently, or cancel entirely.

**Why this priority**: Essential for customer control and reducing cancellations, but secondary to the core order cycle.

**Independent Test**: View schedule management page, perform each action (pause, resume, change frequency, edit items, cancel), verify each action takes effect correctly.

**Acceptance Scenarios**:

1. **Given** I have an active reorder schedule, **When** I click "Pause", **Then** my schedule status changes to paused and no reminder emails are sent
2. **Given** I have a paused schedule, **When** I click "Resume", **Then** my schedule becomes active with next delivery date calculated from today
3. **Given** I have an active schedule, **When** I change the frequency to "Every 2 weeks", **Then** my next delivery date is recalculated
4. **Given** I have an active schedule, **When** I edit the schedule items (add/remove/change quantities), **Then** future pending orders use the updated items
5. **Given** I have an active schedule, **When** I click "Cancel", **Then** my schedule is deactivated and no future reminders are sent

---

### User Story 5 - Skip Next Delivery (Priority: P5)

A customer has sufficient stock and wants to skip their next scheduled delivery without cancelling the entire schedule.

**Why this priority**: Convenience feature that reduces cancellations by giving customers flexibility. Lower priority as it's an optimization.

**Independent Test**: View active schedule, click "Skip Next", verify the pending order is cancelled and next delivery date is advanced.

**Acceptance Scenarios**:

1. **Given** I have an active schedule with a pending order, **When** I click "Skip Next", **Then** the pending order is cancelled
2. **Given** I skipped a delivery, **When** I view my schedule, **Then** the next delivery date is advanced by one frequency interval
3. **Given** I skipped a delivery, **When** the new next delivery date approaches, **Then** I receive a reminder email as normal

---

### Edge Cases

- What happens when a product in the schedule is discontinued or out of stock? System should exclude unavailable items from the pending order and notify the customer in the reminder email.
- What happens if the customer's saved payment method fails? System sends a "payment failed" email with a link to update payment details; order is not placed until payment succeeds.
- What happens if a customer doesn't respond to the reminder email? Pending order expires after the scheduled date; schedule remains active and next cycle proceeds normally.
- What happens if prices change between schedule creation and order confirmation? Customer is charged current prices at confirmation time; reminder email shows current prices.
- What happens if a customer has no saved payment method? They must save one during schedule setup; one-click confirm is only available with a valid saved payment method.
- What happens if a customer creates multiple schedules? Each schedule operates independently; customer receives separate reminder emails for each.

## Requirements *(mandatory)*

### Functional Requirements

**Schedule Setup**
- **FR-001**: System MUST allow logged-in users to create reorder schedules from completed orders
- **FR-002**: System MUST require users to save a payment method when creating a schedule
- **FR-003**: System MUST allow users to select delivery frequency: weekly, every 2 weeks, monthly, every 3 months
- **FR-004**: System MUST calculate and display the next scheduled delivery date based on selected frequency
- **FR-005**: System MUST store the schedule items (products, quantities) from the source order

**Reminder & Pending Order**
- **FR-006**: System MUST create a pending order 3 days before each scheduled delivery date
- **FR-007**: System MUST send a reminder email when a pending order is created
- **FR-008**: Reminder email MUST display order summary with current prices, subtotal, and confirm/edit buttons
- **FR-009**: System MUST use current product prices when creating pending orders (not prices from schedule creation)

**Order Confirmation**
- **FR-010**: System MUST allow one-click order confirmation from the reminder email using saved payment method
- **FR-011**: System MUST allow customers to edit pending orders before confirmation (quantities, add/remove items)
- **FR-012**: System MUST create a real order with order items upon confirmation
- **FR-013**: System MUST charge the customer's saved payment method upon confirmation
- **FR-014**: System MUST advance the schedule's next delivery date upon successful confirmation
- **FR-015**: System MUST send an order confirmation email after successful order placement

**Schedule Management**
- **FR-016**: System MUST display a "My Reorder Schedules" page listing all customer schedules
- **FR-017**: System MUST allow customers to pause and resume schedules
- **FR-018**: System MUST allow customers to change schedule frequency
- **FR-019**: System MUST allow customers to edit schedule items (permanent changes for future orders)
- **FR-020**: System MUST allow customers to cancel schedules
- **FR-021**: System MUST allow customers to skip the next delivery without cancelling
- **FR-022**: System MUST allow customers to update their saved payment method

**Expiration & Failures**
- **FR-023**: System MUST expire pending orders that are not confirmed by the scheduled delivery date
- **FR-024**: System MUST send an expiration notification when a pending order expires
- **FR-025**: System MUST continue to the next scheduled cycle after a pending order expires
- **FR-026**: System MUST send a payment failure notification if the saved payment method is declined
- **FR-027**: System MUST allow retry of payment after updating payment method

**Product Availability**
- **FR-028**: System MUST exclude unavailable products from pending orders
- **FR-029**: System MUST notify customers in the reminder email if any scheduled items are unavailable

### Key Entities

- **ReorderSchedule**: Represents a customer's recurring order setup. Contains delivery frequency, status (active, paused, cancelled), next scheduled date, reference to saved payment method, and the user who owns it.
- **ReorderScheduleItem**: Individual product in a schedule. Contains product reference, quantity, and reference price (for display purposes; actual charge uses current prices).
- **PendingOrder**: Draft order awaiting customer confirmation. Contains items snapshot with current prices, scheduled delivery date, status (pending, confirmed, expired), and reference to parent schedule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can set up a reorder schedule in under 2 minutes from order confirmation
- **SC-002**: One-click confirmation completes in under 10 seconds (from email click to order placed)
- **SC-003**: 80% of reorder schedule holders confirm at least one order within the first 3 months
- **SC-004**: Less than 10% of active schedules are cancelled within the first 3 months
- **SC-005**: Reminder emails are sent within 1 hour of the 3-day-before deadline
- **SC-006**: Zero duplicate orders created from the same pending order
- **SC-007**: 100% of confirmed orders result in successful payment or a payment failure notification
- **SC-008**: Customers can manage their schedules (pause, resume, edit, cancel) without support intervention

## Assumptions

- Users already have accounts and can log in (user authentication exists)
- Stripe is the payment provider with Customer and PaymentMethod support for saved cards
- Email delivery infrastructure exists (order confirmation emails already work)
- Background job processing infrastructure exists for scheduled tasks
- Products have current prices that can be retrieved at pending order creation time
- Guest users cannot create reorder schedules (account required)
