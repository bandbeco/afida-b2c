# Feature Specification: Email Signup Discount

**Feature Branch**: `001-email-signup-discount`
**Created**: 2026-01-16
**Status**: Draft
**Input**: User description: "Offer 5% off the first order for people who sign up to our email list (news and promotions). The aim is to nudge visitors on the fence about putting in an order, and to build a qualified email list that we can market to in the future."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Guest Visitor Claims Discount (Priority: P1)

A first-time visitor browsing the shop adds items to their cart. On the cart page, they see a signup form offering 5% off their first order. They enter their email, submit, and immediately see the discount applied with their calculated savings displayed. When they proceed to checkout, the 5% discount is automatically applied to their order total.

**Why this priority**: This is the core conversion path—the primary reason for building this feature. Without this working, the feature provides no value.

**Independent Test**: Can be fully tested by adding items to cart, entering an email, and verifying the discount appears at checkout. Delivers immediate conversion value.

**Acceptance Scenarios**:

1. **Given** a guest visitor with items in cart, **When** they view the cart page, **Then** they see the email signup form with "Get 5% off" messaging
2. **Given** a guest visitor viewing the signup form, **When** they enter a valid email and submit, **Then** the form is replaced with a success message showing the calculated savings amount
3. **Given** a visitor who has claimed the discount, **When** they proceed to checkout, **Then** the 5% discount is automatically applied to their order total

---

### User Story 2 - Logged-in New Customer Claims Discount (Priority: P1)

A user who created an account but hasn't placed an order yet visits the cart page. They see the same signup form and can claim the discount by entering their email. The experience is identical to guest visitors.

**Why this priority**: Logged-in new customers represent a significant portion of first-time buyers and should have equal access to the offer.

**Independent Test**: Can be tested by logging in with a user account that has no order history, viewing cart, and claiming the discount.

**Acceptance Scenarios**:

1. **Given** a logged-in user with no previous orders, **When** they view the cart page, **Then** they see the email signup form
2. **Given** a logged-in user who claims the discount, **When** they complete checkout, **Then** the 5% discount is applied to their order

---

### User Story 3 - Returning Customer Excluded (Priority: P2)

A logged-in user who has previously placed orders views the cart page. They do not see the discount signup form because the offer is for new customers only.

**Why this priority**: Prevents confusion and potential resentment from existing customers who might feel they "missed out" on a discount.

**Independent Test**: Can be tested by logging in with a user who has order history and verifying the signup form is not displayed.

**Acceptance Scenarios**:

1. **Given** a logged-in user with order history, **When** they view the cart page, **Then** the discount signup form is not displayed

---

### User Story 4 - Previously Subscribed Email Rejected (Priority: P2)

A visitor enters an email address that has already been used to claim the discount. The system recognizes this and displays a message indicating they have already claimed the offer.

**Why this priority**: Prevents abuse and ensures the discount is limited to one use per email address.

**Independent Test**: Can be tested by attempting to sign up with an email that has already been used.

**Acceptance Scenarios**:

1. **Given** a visitor who enters an email already in the subscription list, **When** they submit the form, **Then** they see "You've already claimed this offer" message
2. **Given** a visitor who enters an email associated with previous orders, **When** they submit the form, **Then** they see "This offer is for first-time customers" message

---

### User Story 5 - Email List Captured for Marketing (Priority: P3)

When a visitor signs up for the discount, their email is stored for future marketing communications. The email list can be exported or synced to marketing platforms.

**Why this priority**: This is a secondary benefit—the primary goal is conversion, but building the email list provides long-term marketing value.

**Independent Test**: Can be tested by signing up and verifying the email is stored in the system.

**Acceptance Scenarios**:

1. **Given** a visitor who claims the discount, **When** the transaction completes, **Then** their email is stored with a record of when they subscribed and the source of signup

---

### Edge Cases

- What happens when a guest claims a discount, then creates an account before checkout? The discount remains in their session and is applied.
- What happens when a user's session expires after claiming the discount? They can re-enter their email, but will see "already claimed" message. They may need to contact support or the discount code could be shown in the "already claimed" message.
- What happens when checkout fails after discount is applied? The discount remains available for retry.
- What happens when the cart is empty? The signup form is still displayed (for users browsing before adding items).
- What happens if the visitor refreshes the cart page after claiming the discount? The success state persists and discount remains applied.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a discount signup form on the cart page for eligible visitors
- **FR-002**: System MUST validate that the entered email has not previously claimed the discount
- **FR-003**: System MUST validate that the entered email has no previous orders in the system
- **FR-004**: System MUST NOT display the signup form to logged-in users who have order history
- **FR-005**: System MUST store the email and subscription timestamp when a visitor claims the discount
- **FR-006**: System MUST apply a 5% discount to the order total at checkout for visitors who claimed the discount
- **FR-007**: System MUST display the calculated savings amount after successful signup
- **FR-008**: System MUST validate email format before accepting submission
- **FR-009**: System MUST handle email comparison case-insensitively (bob@example.com = BOB@Example.com)
- **FR-010**: System MUST clear the discount from the session after a successful order is placed
- **FR-011**: System MUST display appropriate error messages for ineligible emails (already claimed vs. existing customer)

### Key Entities

- **Email Subscription**: Represents a visitor who has signed up for the email list. Contains the email address, timestamp of signup, timestamp of discount claim (if applicable), and the source of signup (e.g., cart page).
- **Discount Code**: A single reusable promotional code that provides 5% off. Eligibility is controlled by the application, not the payment system.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Visitors can complete the email signup and see their discount applied in under 10 seconds
- **SC-002**: Cart page conversion rate increases by at least 5% within 30 days of launch
- **SC-003**: At least 100 new email subscriptions are captured within the first 30 days
- **SC-004**: Discount abuse rate (multiple signups from same person) remains below 2% of total signups
- **SC-005**: 95% of eligible visitors see the signup form render correctly on the cart page

## Assumptions

- The existing cart and checkout flow will continue to work as expected
- Visitors who claim the discount in one browser session can complete checkout in the same session
- Email validation uses standard format checking (not verification of deliverability)
- The discount applies to the entire order subtotal (before shipping and tax)
- The discount code is created once and reused; eligibility is controlled by the application
- Guest checkout remains supported alongside the discount feature
