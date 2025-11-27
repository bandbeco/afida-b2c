# Feature Specification: Order User Association

**Feature Branch**: `009-order-user-association`
**Created**: 2025-11-26
**Status**: Complete
**Input**: User description: "When an order is created, if the user is currently logged in, that order should be associated to this user, so that they can view their order and order history."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Order History (Priority: P1)

A logged-in user navigates to their order history page to see all orders they have placed. They can see a list of their past orders with key information (order number, date, total, status) and click on any order to view its details.

**Why this priority**: This is the core value proposition - users need to access their order history to track purchases, reference past orders, and manage their account effectively.

**Independent Test**: Can be fully tested by having a logged-in user with existing orders navigate to the orders page and verify they see only their orders with correct details.

**Acceptance Scenarios**:

1. **Given** a logged-in user with 3 past orders, **When** they navigate to the order history page, **Then** they see all 3 orders listed with order number, date, status, and total for each
2. **Given** a logged-in user with no past orders, **When** they navigate to the order history page, **Then** they see an empty state message indicating no orders exist
3. **Given** a logged-in user, **When** they click on an order in their order history, **Then** they are taken to the order details page showing full order information

---

### User Story 2 - Order Associated at Checkout (Priority: P1)

When a logged-in user completes checkout and payment, the resulting order is automatically associated with their account. They can immediately view the order in their order history after purchase.

**Why this priority**: This is the foundational mechanism that enables all other order history functionality. Without this, users cannot build an order history.

**Independent Test**: Can be fully tested by logging in, completing a purchase, and verifying the new order appears in the user's order history.

**Acceptance Scenarios**:

1. **Given** a logged-in user with items in their cart, **When** they complete checkout and payment, **Then** the created order is associated with their user account
2. **Given** a logged-in user who just completed checkout, **When** they navigate to their order history, **Then** the new order appears in the list
3. **Given** a guest user (not logged in) with items in their cart, **When** they complete checkout and payment, **Then** the order is created without a user association

---

### User Story 3 - Order Access Authorization (Priority: P1)

Users can only view orders that belong to them. Attempting to access another user's order results in appropriate access denial.

**Why this priority**: This is a security requirement - users must not be able to view other customers' order information (addresses, items purchased, payment details).

**Independent Test**: Can be fully tested by attempting to access an order URL belonging to a different user and verifying access is denied.

**Acceptance Scenarios**:

1. **Given** a logged-in user, **When** they attempt to view an order that belongs to them, **Then** they can view the order details
2. **Given** a logged-in user, **When** they attempt to view an order that belongs to a different user, **Then** they are denied access with an appropriate message
3. **Given** a guest user (not logged in), **When** they attempt to access an order details page directly via URL, **Then** they are redirected to login

---

### Edge Cases

- What happens when a user creates an account after placing guest orders? (Orders placed as guest remain unassociated - no retroactive linking)
- What happens if a user logs in during checkout after starting as a guest? (Order should be associated with the logged-in user at time of payment completion)
- How are orders displayed when a user is part of an organization? (Organization orders are handled separately and out of scope for this feature)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST associate orders with the logged-in user when checkout is completed
- **FR-002**: System MUST allow logged-in users to view a list of their past orders
- **FR-003**: System MUST restrict order viewing to only orders belonging to the logged-in user
- **FR-004**: System MUST display order history in reverse chronological order (most recent first)
- **FR-005**: System MUST show order number, date, status, and total amount in order list
- **FR-006**: System MUST allow users to click through from order list to order details
- **FR-007**: System MUST display an empty state when a user has no orders
- **FR-008**: System MUST redirect unauthenticated users to login when attempting to access order pages
- **FR-009**: System MUST redirect users to an appropriate page with error message when attempting to access another user's order

### Key Entities

- **User**: Customer account with authentication credentials; owns zero or more orders
- **Order**: Purchase transaction record; belongs to zero or one user (guest orders have no user)
- **Order History**: List view of orders belonging to a specific user

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of orders placed by logged-in users are correctly associated with their account
- **SC-002**: Users can view their complete order history within 2 seconds of page load
- **SC-003**: 100% of unauthorized order access attempts are blocked
- **SC-004**: Users can navigate from order history to order details in a single click
- **SC-005**: Order history page clearly communicates when no orders exist

## Assumptions

- The database already has a user_id column on the orders table (confirmed: `belongs_to :user, optional: true`)
- Users already have an account and authentication mechanism in place (confirmed: Rails 8 authentication)
- Guest checkout functionality should continue to work (orders created without user association)
- Order history is accessed through a dedicated page in the user's account area
- No retroactive association of guest orders to newly created accounts (out of scope)
- Organization orders are handled separately and are out of scope for this feature
