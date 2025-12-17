# Feature Specification: User Address Storage

**Feature Branch**: `001-user-address-storage`
**Created**: 2025-12-17
**Status**: Draft
**Input**: User description: "Allow logged-in users to save multiple delivery addresses for faster checkout with Stripe prefill"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manage Saved Addresses (Priority: P1)

As a logged-in user, I want to add, edit, and delete my delivery addresses in my account settings so that I can maintain an up-to-date list of places I ship to.

**Why this priority**: This is the foundational capability. Without address management, users cannot save addresses to use at checkout. This must exist before any checkout integration can work.

**Independent Test**: Can be fully tested by logging in, navigating to account settings, adding an address with all fields, editing it, setting it as default, and deleting it. Delivers value by allowing users to prepare their addresses before checkout.

**Acceptance Scenarios**:

1. **Given** I am logged in and on the addresses page, **When** I click "Add new address" and fill in required fields (nickname, recipient name, address line 1, city, postcode), **Then** the address is saved and appears in my list.
2. **Given** I have a saved address, **When** I click "Edit" and change the recipient name, **Then** the updated name is saved and displayed.
3. **Given** I have multiple addresses, **When** I click "Set as default" on a non-default address, **Then** that address becomes the default and any previous default is unmarked.
4. **Given** I have an address, **When** I click "Delete" and confirm, **Then** the address is removed from my list.
5. **Given** I delete my default address and have other addresses, **When** the deletion completes, **Then** the oldest remaining address becomes the new default.

---

### User Story 2 - Select Address at Checkout (Priority: P2)

As a logged-in user with saved addresses, I want to select which address to use when I checkout so that Stripe prefills my delivery details and I don't have to type them again.

**Why this priority**: This delivers the core value proposition - faster checkout. Depends on P1 (addresses must exist to select from).

**Independent Test**: Can be tested by having at least one saved address, adding items to cart, clicking checkout, selecting an address from the modal, proceeding to Stripe, and verifying the address fields are prefilled.

**Acceptance Scenarios**:

1. **Given** I am logged in with saved addresses and have items in my cart, **When** I click "Checkout", **Then** a modal appears showing my saved addresses with the default pre-selected.
2. **Given** the checkout modal is open, **When** I select a saved address and click "Continue to checkout", **Then** I am redirected to Stripe Checkout with my address prefilled.
3. **Given** the checkout modal is open, **When** I select "Enter a different address" and click "Continue", **Then** I am redirected to Stripe Checkout with empty address fields.
4. **Given** I am logged in with NO saved addresses, **When** I click "Checkout", **Then** I go directly to Stripe Checkout without seeing the address selection modal.
5. **Given** I am not logged in (guest), **When** I click "Checkout", **Then** I go directly to Stripe Checkout without seeing any address selection.

---

### User Story 3 - Save Address After Checkout (Priority: P3)

As a logged-in user who just completed an order using a new address, I want to be prompted to save that address so that I can reuse it for future orders without manually adding it.

**Why this priority**: This is a convenience enhancement. Core functionality works without it, but it improves the user experience for repeat customers.

**Independent Test**: Can be tested by completing checkout with a new address (not matching any saved addresses), viewing the confirmation page, entering a nickname, and verifying the address is saved to the account.

**Acceptance Scenarios**:

1. **Given** I am logged in and just completed an order with a new address, **When** I land on the order confirmation page, **Then** I see a prompt asking "Save this address for faster checkout?" with the address displayed.
2. **Given** I see the save address prompt, **When** I enter a nickname and click "Save", **Then** the address is added to my saved addresses.
3. **Given** I see the save address prompt, **When** I click "No thanks", **Then** the prompt disappears and the address is not saved.
4. **Given** I am logged in and just completed an order using a saved address (matching line1 and postcode), **When** I land on the confirmation page, **Then** I do NOT see the save address prompt.
5. **Given** I am not logged in (guest checkout), **When** I complete an order, **Then** I do NOT see the save address prompt.

---

### Edge Cases

- What happens when a user tries to add an address with missing required fields? System shows validation errors and does not save.
- What happens when a user deletes their only address? The address is deleted and no default exists until they add a new one.
- What happens when the checkout modal loads but the user has no default set? The first address in the list is pre-selected.
- What happens if Stripe is unavailable when user clicks checkout with a saved address? Standard Stripe error handling applies; address selection is not affected.
- What happens if user has exactly one address? Modal still shows with that address pre-selected and "Enter different address" option available.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow logged-in users to create, read, update, and delete delivery addresses.
- **FR-002**: System MUST require nickname, recipient name, address line 1, city, and postcode for each address.
- **FR-003**: System MUST allow optional company name, address line 2, and phone number for each address.
- **FR-004**: System MUST allow users to designate one address as their default delivery address.
- **FR-005**: System MUST ensure only one address per user can be marked as default at any time.
- **FR-006**: System MUST automatically assign a new default when the current default address is deleted (oldest remaining).
- **FR-007**: System MUST display an address selection modal when a logged-in user with saved addresses clicks checkout.
- **FR-008**: System MUST pre-select the user's default address in the checkout modal.
- **FR-009**: System MUST pass the selected address to Stripe Checkout for prefilling.
- **FR-010**: System MUST provide an option to "Enter a different address" in the checkout modal, bypassing prefill.
- **FR-011**: System MUST skip the address selection modal for guest users and users with no saved addresses.
- **FR-012**: System MUST prompt logged-in users to save new addresses after successful checkout.
- **FR-013**: System MUST only show the save prompt when the order's address does not match any saved addresses.
- **FR-014**: System MUST restrict address access to the owning user only (no cross-user access).
- **FR-015**: System MUST support UK addresses only (country hardcoded to GB).

### Key Entities

- **Address**: A delivery location saved by a user. Contains nickname (for identification), recipient name, optional company name, street address (line 1 and optional line 2), city, postcode, optional phone, and a default flag. Belongs to exactly one user.
- **User**: Extended to own multiple addresses. Has a default address (if any addresses exist).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Logged-in users can add a new address in under 60 seconds.
- **SC-002**: Repeat customers complete checkout 50% faster when using saved addresses (measured by time from cart to payment submission).
- **SC-003**: 80% of users who complete checkout with a new address save it when prompted.
- **SC-004**: Users with saved addresses see the address selection modal within 500ms of clicking checkout.
- **SC-005**: 100% of saved addresses are correctly prefilled in Stripe Checkout (verified by comparing submitted address to saved address).
- **SC-006**: Zero unauthorized access to other users' addresses (security requirement).

## Assumptions

- Users primarily ship to UK addresses (GB only for this release).
- Stripe Checkout will accept and display prefilled address data via the customer_details parameter.
- The existing account settings area can accommodate a new "Addresses" section.
- Logged-in users have verified email addresses (existing system requirement).
- Address matching for the save prompt uses a simple comparison (line1 + postcode) rather than fuzzy matching.
