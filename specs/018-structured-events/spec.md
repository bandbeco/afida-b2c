# Feature Specification: Structured Events Infrastructure

**Feature Branch**: `018-structured-events`
**Created**: 2026-01-16
**Status**: Draft
**Input**: User description: "Implement application-wide structured event reporting using Rails 8.1 Rails.event API for tracking customer journey and operational events, with events flowing to Logtail for querying and debugging"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Debug Silent Failures (Priority: P1)

As a developer, I need to trace the sequence of events that occurred before and after an issue, so I can debug problems that don't throw exceptions (e.g., "the order wasn't created after the webhook arrived").

**Why this priority**: Silent failures are the most frustrating to debug. Without structured events, developers must guess what happened. This is the core pain point driving this feature.

**Independent Test**: Can be fully tested by triggering a webhook, querying Logtail for events with that webhook ID, and seeing the full sequence of what happened.

**Acceptance Scenarios**:

1. **Given** a Stripe webhook is received, **When** I search for that webhook's event ID in Logtail, **Then** I see all related events (received, processed/failed, payment status, order creation) with timestamps in chronological order.
2. **Given** a customer reports "my order didn't go through," **When** I search by their email address, **Then** I see their complete journey (cart events, checkout events, payment events) and can identify where the process broke down.
3. **Given** an event is emitted, **When** I view it in Logtail, **Then** I see the event name, payload, request context (request_id, user_id), timestamp, and source code location.

---

### User Story 2 - Track Email Signup Funnel (Priority: P2)

As a business owner, I need to understand how many visitors sign up for the email list, claim the discount, and place their first order, so I can measure the effectiveness of the email signup promotion.

**Why this priority**: This was the original motivation for the feature. Understanding conversion rates directly impacts marketing ROI.

**Independent Test**: Can be fully tested by signing up with an email, claiming the discount at checkout, placing an order, then querying Logtail to see the complete funnel events for that email.

**Acceptance Scenarios**:

1. **Given** a visitor submits the email signup form, **When** the form is processed, **Then** an `email_signup.completed` event is logged with their email, source location, and discount eligibility status.
2. **Given** a subscriber uses their discount at checkout, **When** the order is placed, **Then** an `email_signup.discount_claimed` event is logged linking the email to the order.
3. **Given** I want to see funnel performance, **When** I query Logtail for email signup events over a date range, **Then** I can calculate signup count, discount claim rate, and conversion to first order.

---

### User Story 3 - Monitor Payment Issues (Priority: P2)

As a business owner, I need to see when payments fail and why, so I can identify patterns (e.g., specific card types, regions) and reduce lost sales.

**Why this priority**: Payment failures directly impact revenue. Quick visibility into failure patterns enables proactive fixes.

**Independent Test**: Can be fully tested by simulating a declined payment, then querying Logtail to see the payment.failed event with error details.

**Acceptance Scenarios**:

1. **Given** a payment fails during checkout, **When** Stripe notifies the system, **Then** a `payment.failed` event is logged with the customer email, amount, error code, and decline reason.
2. **Given** I want to analyze payment failures, **When** I query for `payment.failed` events over the past week, **Then** I can see patterns in error codes and take action.
3. **Given** a payment succeeds, **When** Stripe confirms the payment, **Then** a `payment.succeeded` event is logged with order ID, amount, and payment intent ID.

---

### User Story 4 - Track Customer Cart Activity (Priority: P3)

As a business analyst, I need to understand cart behavior (items added, removed), so I can identify popular products and potential friction points.

**Why this priority**: Cart activity provides valuable insights but is less urgent than debugging and funnel tracking.

**Independent Test**: Can be fully tested by adding and removing items from a cart, then querying Logtail to see the cart events with product details.

**Acceptance Scenarios**:

1. **Given** a customer adds a product to their cart, **When** the item is added, **Then** a `cart.item_added` event is logged with product ID, SKU, quantity, and whether it's a sample.
2. **Given** a customer removes a product from their cart, **When** the item is removed, **Then** a `cart.item_removed` event is logged with product ID and SKU.

---

### User Story 5 - Track Scheduled Reorder Lifecycle (Priority: P3)

As a business owner, I need visibility into the scheduled reorder system, so I can monitor subscription health and identify when customers fail to confirm or payments fail.

**Why this priority**: Scheduled reorders are a revenue stream, but lower volume than one-time purchases.

**Independent Test**: Can be fully tested by creating a reorder schedule, triggering the pending order creation job, and querying Logtail to see the lifecycle events.

**Acceptance Scenarios**:

1. **Given** a customer sets up a reorder schedule, **When** the schedule is created, **Then** a `reorder.scheduled` event is logged with schedule ID, frequency, and item count.
2. **Given** the system creates a pending order, **When** the job runs, **Then** a `pending_order.created` event is logged with pending order ID, schedule ID, and total.
3. **Given** a customer confirms their pending order, **When** payment succeeds, **Then** a `reorder.confirmed` event is logged linking the order to the schedule.
4. **Given** a scheduled payment fails, **When** the charge is declined, **Then** a `reorder.charge_failed` event is logged with schedule ID, email, and error code.

---

### Edge Cases

- What happens when an event is emitted but the log destination is unreachable? Events are logged to the standard Rails logger as a fallback; no data is lost locally.
- What happens when the same logical action triggers multiple events? Each event is independent with its own timestamp, allowing reconstruction of the sequence.
- How does the system handle high event volume? Events are logged asynchronously via the standard logging infrastructure; no blocking or queuing needed.
- What happens in test environments? Events are emitted to the test logger, enabling assertion-based testing of event emission.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST emit structured events using a consistent `domain.action` naming pattern (e.g., `order.placed`, `payment.failed`).
- **FR-002**: System MUST include relevant identifiers in every event payload (e.g., order_id, user_id, email) to enable cross-referencing.
- **FR-003**: System MUST set request context (request_id, user_id, session_id) once per request so all events within that request share common metadata.
- **FR-004**: System MUST format events as structured data including event name, payload, context, tags, timestamp, and source location.
- **FR-005**: System MUST emit events for the complete customer journey: email signup, cart activity, checkout, order placement.
- **FR-006**: System MUST emit events for operational workflows: webhook receipt/processing, payment success/failure, order fulfillment/cancellation.
- **FR-007**: System MUST emit events for the scheduled reorder lifecycle: schedule creation, pending order creation, confirmation, charge failures.
- **FR-008**: System MUST use past tense for completed action events (e.g., `completed`, `placed`, `failed`) to maintain naming consistency.
- **FR-009**: System MUST include a `source` field in events where the origin matters (e.g., `source: "cart"`, `source: "webhook"`).
- **FR-010**: System MUST route events to a configurable log destination via a subscriber pattern, allowing future destinations to be added.

### Key Entities

- **Event**: A structured record of something that happened, containing a name, payload, context, tags, timestamp, and source location. Events are immutable once emitted.
- **Subscriber**: A component that receives events and routes them to a destination. Multiple subscribers can receive the same event, enabling multi-destination routing.
- **Context**: Request-scoped metadata (request_id, user_id, session_id) automatically attached to all events within a request.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can trace any customer's complete journey by searching their email address, seeing all related events within 30 seconds.
- **SC-002**: Developers can identify the root cause of a silent failure (e.g., missing order after webhook) by querying related events within 5 minutes.
- **SC-003**: Business owners can determine the email signup conversion funnel (signup to discount claimed to first order) by querying events.
- **SC-004**: 100% of customer journey touchpoints (signup, cart, checkout, order) emit corresponding events.
- **SC-005**: 100% of operational workflows (webhooks, payments, order lifecycle) emit corresponding events.
- **SC-006**: Events are queryable by event name, payload fields (email, order_id), and date range.
- **SC-007**: Adding a new event type requires only a single line of code at the emit location.

## Assumptions

- A structured logging service will be configured as the production log destination with JSON parsing enabled.
- The application is running a version of Rails that supports the structured event reporting API.
- Events are for server-side tracking only; frontend events (e.g., form viewed) are out of scope for this iteration.
- Event data follows the same privacy handling as existing application logs; no additional PII handling is required.
- Current event volume fits within standard logging infrastructure capacity.

## Out of Scope

- Real-time dashboards or admin UI for viewing events (use the log service's UI).
- Frontend JavaScript event tracking (may be added in a future iteration).
- Analytics platform integration (architecture is ready, but integration deferred).
- Schematized event classes (using convention-based approach for simplicity).
- Alerting on event patterns (can be configured in the log service separately).
