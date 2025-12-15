# Feature Specification: Stripe Subscription Checkout

**Feature Branch**: `012-stripe-subscriptions`
**Created**: 2025-12-15
**Status**: Draft
**Input**: User description: "Complete Stripe subscription checkout flow with cart UI toggle, subscription checkout controller, webhook sync for automatic order creation"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set Up Recurring Order from Cart (Priority: P1)

A logged-in customer wants to receive their regular supplies automatically without having to place repeat orders manually. They add items to their cart and choose to make it a recurring order before checkout.

**Why this priority**: Core value proposition - enables hands-off repeat ordering which drives customer retention and increases lifetime value for B2B customers who order the same supplies regularly.

**Independent Test**: Log in, add items to cart, toggle "Make this recurring", select frequency, complete checkout, verify subscription created and first order placed.

**Acceptance Scenarios**:

1. **Given** I am logged in and have items in my cart, **When** I view the cart, **Then** I see a "Make this a recurring order" toggle with frequency options
2. **Given** I have toggled recurring order on and selected "Every 2 Weeks", **When** I click "Subscribe & Checkout", **Then** I am taken to a payment page for subscription setup
3. **Given** I have completed subscription checkout successfully, **When** I am redirected back, **Then** I see an order confirmation and my subscription is created with status "active"
4. **Given** I have completed subscription checkout, **When** I visit my subscriptions page, **Then** I see my new subscription with correct frequency and next billing date

---

### User Story 2 - Automatic Order Creation on Renewal (Priority: P2)

Once a customer has an active subscription, the system should automatically create and process orders on the scheduled billing dates without any customer intervention.

**Why this priority**: Fulfills the core promise of recurring orders - customers expect their subscription to "just work" after initial setup. Without this, subscriptions have no practical benefit.

**Independent Test**: Set up subscription, wait for billing cycle (or simulate via webhook), verify order is created and email is sent.

**Acceptance Scenarios**:

1. **Given** I have an active subscription, **When** my billing cycle renews, **Then** a new order is automatically created with the same items as my subscription
2. **Given** my subscription renews automatically, **When** the order is created, **Then** I receive an email notification about the order
3. **Given** my subscription renews, **When** I view my order history, **Then** I see the new order linked to my subscription

---

### User Story 3 - Subscription Status Sync from External Changes (Priority: P3)

If a subscription is modified outside the application (e.g., cancelled via Stripe Dashboard, payment fails), the system should reflect these changes accurately.

**Why this priority**: Ensures data integrity and prevents customer confusion. Without sync, customers may see incorrect status leading to support tickets and trust issues.

**Independent Test**: Cancel subscription in Stripe Dashboard, verify local status updates to cancelled.

**Acceptance Scenarios**:

1. **Given** my subscription is active, **When** it is cancelled via Stripe Dashboard, **Then** my subscription page shows status "cancelled"
2. **Given** my subscription is active, **When** it is paused externally, **Then** my subscription page shows status "paused"
3. **Given** my subscription status changes externally, **When** I view my subscriptions, **Then** I see the accurate current status

---

### User Story 4 - Guest User Subscription Prompt (Priority: P4)

Guest users browsing the cart should understand that subscriptions are available but require an account, encouraging sign-up.

**Why this priority**: Drives account creation without blocking the primary purchase flow. Secondary to core subscription functionality.

**Independent Test**: Visit cart as guest, verify subscription toggle shows sign-in prompt.

**Acceptance Scenarios**:

1. **Given** I am not logged in and have items in my cart, **When** I view the cart, **Then** I see a disabled subscription toggle with message "Sign in to set up recurring orders"
2. **Given** I am a guest viewing the disabled toggle, **When** I click the sign-in link, **Then** I am redirected to sign-in with a return URL to the cart

---

### Edge Cases

- What happens when a subscription item is no longer available? System should proceed with remaining items and notify customer.
- How does system handle payment failure during subscription renewal? Stripe handles retry logic; system logs warning and status updates via webhook.
- What if user already has existing items in cart and tries to subscribe? Subscription includes all current cart items.
- What happens if user tries to subscribe with samples-only cart? Samples cannot be subscribed - toggle should be disabled with explanatory message.

## Requirements *(mandatory)*

### Functional Requirements

**Cart Subscription UI**
- **FR-001**: System MUST display subscription toggle only to logged-in users
- **FR-002**: System MUST show disabled toggle with sign-in prompt to guest users
- **FR-003**: When subscription toggle is enabled, system MUST display frequency selector with options: Weekly, Every 2 Weeks, Monthly, Every 3 Months
- **FR-004**: When subscription is enabled, system MUST display a separate "Subscribe & Checkout" button alongside the regular checkout button
- **FR-005**: System MUST disable subscription toggle for carts containing only sample items

**Subscription Checkout**
- **FR-006**: System MUST require authentication before processing subscription checkout
- **FR-007**: System MUST create a recurring billing session with the payment provider
- **FR-008**: System MUST create a local subscription record upon successful checkout completion
- **FR-009**: System MUST create the first order and order items upon successful subscription checkout
- **FR-010**: System MUST store subscription details including frequency, items snapshot, and shipping address
- **FR-011**: System MUST clear the cart after successful subscription checkout
- **FR-012**: System MUST send order confirmation email after subscription checkout

**Automatic Order Processing**
- **FR-013**: System MUST create a new order when subscription billing renews successfully
- **FR-014**: System MUST populate renewal orders from the stored items snapshot
- **FR-015**: System MUST send notification email when automatic order is created
- **FR-016**: System MUST link renewal orders to the parent subscription

**Status Synchronization**
- **FR-017**: System MUST update subscription status when changed externally (cancelled, paused, resumed)
- **FR-018**: System MUST update subscription billing period dates when subscription renews
- **FR-019**: System MUST log payment failures from the payment provider

### Key Entities

- **Subscription**: Recurring order configuration linked to a user. Stores frequency, status (active/paused/cancelled), payment provider IDs, items snapshot (products, quantities, prices at subscription time), shipping snapshot, and billing period dates.
- **Order**: Completed purchase. Can optionally belong to a subscription for renewal orders.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can set up a recurring order in under 3 minutes (from cart to subscription confirmation)
- **SC-002**: 95% of subscription renewals result in successful automatic order creation
- **SC-003**: Subscription status updates sync within 5 minutes of external changes
- **SC-004**: Users can view and understand their subscription details (frequency, next delivery, items) within 10 seconds of visiting subscriptions page
- **SC-005**: Zero duplicate orders created from the same billing event
- **SC-006**: 100% of automatic renewal orders trigger email notification to customer

## Assumptions

- Existing subscription model and management UI (view, pause, resume, cancel) are already implemented
- Routes for subscription_checkouts are already configured
- Payment provider (Stripe) credentials and SDK are already set up
- Products do not exist in payment provider catalog; prices are created dynamically at checkout
- VAT calculation follows existing checkout patterns (20% UK rate)
- Shipping options for subscriptions match one-time order shipping
