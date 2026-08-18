import { Controller } from "@hotwired/stimulus"

// On-site checkout: binds the page to a Stripe Checkout Session (ui_mode:
// "custom") created server-side. Stripe's SDK owns the money math; this
// controller mounts the secure elements, mirrors session totals into the
// summary, reprices shipping from the typed delivery address, applies/removes
// promo codes, and confirms. API per https://docs.stripe.com/js/custom_checkout.
//
// Money lines: total, VAT, and discount re-render from the SDK; shipping
// re-renders from the reprice response (shipping rides as a Stripe LINE ITEM,
// see Checkout::SessionBuilder, so the SDK cannot report it separately - and
// session.total.subtotal INCLUDES it, which is why the goods-only "Subtotal"
// row stays server-rendered and never moves; there is no on-page cart editing).
//
// Shipping reprice: the shipping Address Element's change event (complete +
// value) triggers a PATCH /checkout with the typed postcode, wrapped in
// actions.runServerUpdate() so the SDK refetches the session and refreshes
// totals after the server rebuilds the shipping line item. The address itself
// syncs to Stripe client-side as it always has - the server owns only the
// price. While a reprice is in flight the Pay button is locked, a FAILED
// reprice locks it too (fail closed) until a retry succeeds, and the zone
// guard below independently blocks Pay whenever the typed postcode's zone
// disagrees with the zone the session is priced for, so a missed reprice
// cannot be paid at the wrong price either.
// (permissions.update_shipping_details=server_only is deliberately NOT used:
// the clover elements SDK rejects onShippingDetailsChange at init, and under
// server_only it throws when applying defaultValues - see SessionBuilder.)
export default class extends Controller {
  static targets = [
    "email", "address", "billingAddress", "payment", "payButton", "error",
    "totalLine", "discountRow", "zoneWarning",
    "promoSection", "promoForm", "promoInput", "promoApplied", "promoCode", "promoError"
  ]

  static values = {
    clientSecret: String,
    publishableKey: String,
    pricedZone: String,
    guest: Boolean,
    prefill: Object
  }

  async connect() {
    this.zoneOk = true

    if (!window.Stripe) return this.fatal()

    try {
      this.stripe = Stripe(this.publishableKeyValue)
      this.checkout = await this.stripe.initCheckoutElementsSdk({
        clientSecret: this.clientSecretValue,
        defaultValues: this.defaultValues(),
        // Puts Stripe's "same as shipping" checkbox on the billing element so
        // most shoppers never type their address twice. Documented as the
        // default when both address elements share one Elements instance, but
        // the clover SDK does not apply it unless set explicitly.
        elementsOptions: { syncAddressCheckbox: "billing" }
      })
      // loadActions resolves to a {type, actions} result wrapper; the
      // callable actions (updateEmail, confirm, ...) live one level down.
      const loaded = await this.checkout.loadActions()
      if (!loaded?.actions) throw new Error(`loadActions returned type ${loaded?.type}`)
      this.actions = loaded.actions
    } catch (error) {
      console.error("[onsite-checkout] init failed:", error)
      return this.fatal()
    }

    // The awaits above straddle navigation: if the shopper already left the
    // page, mounting into the departed DOM would leak live Stripe elements.
    if (!this.element.isConnected) return

    this.paymentElement = this.checkout.createPaymentElement()
    this.paymentElement.mount(this.paymentTarget)
    this.addressElement = this.checkout.createShippingAddressElement()
    this.addressElement.mount(this.addressTarget)
    // Every completed state of the address form offers its postcode to the
    // reprice; the server skips Stripe when the zone is unchanged.
    this.addressElement.on("change", (event) => this.shippingAddressChanged(event))
    // The session sets billing_address_collection "required", and in custom
    // mode the Payment Element does NOT collect billing: without this element
    // canConfirm never turns true and the Pay button stays dead. Sharing the
    // Elements instance with the shipping element gives it Stripe's own
    // "same as shipping" checkbox (syncAddressCheckbox defaults to billing).
    this.billingAddressElement = this.checkout.createBillingAddressElement()
    this.billingAddressElement.mount(this.billingAddressTarget)

    this.checkout.on("change", (session) => this.sessionChanged(session))
    this.sessionChanged(this.actions.getSession())
  }

  // The page is marked turbo-cache-control no-cache, so leaving always tears
  // the controller down and Back re-renders server-side; drop timers and
  // elements here so late SDK callbacks can't fire into the departed DOM.
  disconnect() {
    clearTimeout(this.zoneTimer)
    this.paymentElement?.destroy?.()
    this.addressElement?.destroy?.()
    this.billingAddressElement?.destroy?.()
    this.paymentElement = this.addressElement = this.billingAddressElement = null
    this.checkout = this.actions = this.session = null
  }

  // Prefill for logged-in customers: the saved address #create synced to
  // Stripe, and nothing else (their email is already on the session via
  // customer/customer_email). Guests start blank and type both.
  defaultValues() {
    const prefill = this.prefillValue || {}
    if (!prefill.line1) return undefined

    const { name, ...address } = prefill
    return { shippingAddress: { name, address } }
  }

  // --- session state → page ---

  sessionChanged(session) {
    if (!this.element.isConnected) return // SDK callbacks can outlive the page

    this.renderTotals(session)
    this.guardZone(session)
    this.session = session
    this.syncPayButton()
  }

  renderTotals(session) {
    // SDK amounts arrive pre-formatted (session.total.*.amount) in the
    // session's currency; minorUnitsAmount backs the zero checks.
    const total = session?.total
    if (!total) return

    if (total.total?.amount) this.totalLineTarget.textContent = total.total.amount
    this.updateMoneyLine("vat", total.taxExclusive?.amount)

    const discount = total.discount
    const discountActive = (discount?.minorUnitsAmount || 0) > 0
    if (discountActive) this.updateMoneyLine("discount", `-${discount.amount}`)
    if (this.hasDiscountRowTarget) {
      this.discountRowTarget.classList.toggle("hidden", !discountActive)
      this.discountRowTarget.classList.toggle("flex", discountActive)
    }
  }

  updateMoneyLine(kind, formattedAmount) {
    if (!formattedAmount) return
    const el = this.element.querySelector(`[data-onsite-checkout-money-kind='${kind}']`)
    if (el) el.textContent = formattedAmount
  }

  syncPayButton() {
    this.payButtonTarget.disabled =
      this.repricing || !this.zoneOk || this.session?.canConfirm === false
  }

  // --- shipping reprice (the server is the only writer of shipping details) ---

  // Each distinct postcode in a COMPLETED address form is offered to the
  // server exactly once; the server answers cheaply (no Stripe call) when the
  // zone is unchanged, so the on-mount completion of a prefilled address
  // costs one app round-trip.
  shippingAddressChanged(event) {
    if (!event?.complete) return

    const postcode = this.normalisePostcode(event.value?.address?.postal_code)
    if (!postcode || postcode === this.lastRepricedPostcode || postcode === this.inFlightPostcode) return

    this.reprice(postcode)
  }

  // Mirrors ShippingZone.normalise server-side, so two spellings of the same
  // postcode ("iv1 1aa" vs "IV1 1AA") dedupe to one reprice instead of burning
  // requests against the endpoint's rate limit.
  normalisePostcode(postcode) {
    return (postcode || "").toUpperCase().trim().replace(/ +/g, " ")
  }

  // Fail-CLOSED on money: only a 200 (the server repriced, or confirmed the
  // zone unchanged) updates the priced zone; any failure locks Pay directly
  // (zoneOk = false) - the zone guard cannot be the backstop here, because it
  // fails OPEN and shares failure modes with this request (the app briefly
  // down, the customer's network dropping). The PATCH rides inside
  // actions.runServerUpdate() so the SDK refetches the session afterwards and
  // re-renders totals.
  async reprice(postcode) {
    // Only the latest reprice owns the verdict: a slow response for an earlier
    // postcode must not overwrite a later one (same rule as checkZone).
    const seq = (this.repriceSeq = (this.repriceSeq || 0) + 1)
    this.inFlightPostcode = postcode
    this.repricing = true
    this.syncPayButton()

    let repriced = null
    try {
      const response = await this.actions.runServerUpdate(async () => {
        const resp = await fetch("/checkout", {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']")?.content
          },
          body: JSON.stringify({ postcode })
        })

        if (resp.ok) {
          repriced = await resp.json()
          return
        }

        // The stash is gone or stale (basket changed, checkout expired): this
        // page can no longer complete; the cart is the only working restart.
        if (resp.status === 409 || resp.status === 410) {
          window.location.assign("/cart")
          throw new Error("This checkout is no longer active.")
        }

        const body = await resp.json().catch(() => ({}))
        throw new Error(body.error || "We couldn't update delivery for that address. Please try again.")
      })

      // response.type "error" means Stripe's own session refetch failed AFTER
      // our server already updated the session; the reprice itself stands, so
      // fall through and apply it - the next change event re-syncs totals.
      if (response?.type === "error") {
        console.error("[onsite-checkout] session refresh failed after reprice:", response.error)
      }

      if (repriced && seq === this.repriceSeq) {
        this.lastRepricedPostcode = postcode
        this.pricedZoneValue = repriced.zone
        this.updateMoneyLine("shipping", repriced.shipping_amount)
        this.zoneOk = true
        this.zoneWarningTarget.classList.add("hidden")
        this.errorTarget.classList.add("hidden")
      }
    } catch (error) {
      // Thrown from the update function (server refusal / network drop), or by
      // runServerUpdate itself (e.g. timeout). The typed address may now be in
      // a zone the session is not priced for, so lock Pay until a retry
      // succeeds (editing any address field re-fires the reprice) or the zone
      // guard positively confirms the typed zone matches the priced one.
      if (seq === this.repriceSeq) {
        this.zoneOk = false
        this.showError(error?.message || "We couldn't update delivery. Please check your address and try again.")
      }
    } finally {
      // Guarded like the success block: a superseded reprice resolving late
      // must not clear the in-flight flags (unlocking Pay, and re-arming the
      // dedup) while the latest reprice is still running.
      if (seq === this.repriceSeq) {
        this.inFlightPostcode = null
        this.repricing = false
        this.syncPayButton()
      }
    }
  }

  // --- zone guard (fail-safe layer behind the reprice; failures fail open) ---
  // The reprice is the pricing authority; this guard only catches a session
  // whose priced zone somehow drifted from the typed postcode anyway (a missed
  // callback, a reprice the server refused after the address already synced).

  guardZone(session) {
    const postcode = session?.shippingAddress?.address?.postal_code
    if (!postcode || postcode === this.lastCheckedPostcode) return

    this.lastCheckedPostcode = postcode
    clearTimeout(this.zoneTimer)
    this.zoneTimer = setTimeout(() => this.checkZone(postcode), 400)
  }

  async checkZone(postcode) {
    let zoneOk = true // fail open (incl. non-200): no worse than hosted checkout today
    try {
      const response = await fetch(`/shipping_zone?postcode=${encodeURIComponent(postcode)}`)
      if (response.ok) {
        const { zone } = await response.json()
        zoneOk = zone === this.pricedZoneValue
      }
    } catch {
      // fail open
    }

    // Only the latest postcode owns the verdict: a slow response for an
    // earlier one must not overwrite it (last-response-wins race).
    if (postcode !== this.lastCheckedPostcode) return
    // And the reprice lane outranks this one while it has a PATCH in flight:
    // this comparison may have read the priced zone that reprice is about to
    // replace, and applying it would clobber the fresh verdict with a stale
    // one - then stick, because both lanes dedupe by postcode. The reprice's
    // own outcome sets zoneOk either way (success true, failure false).
    if (this.repricing) return

    this.zoneOk = zoneOk
    this.zoneWarningTarget.classList.toggle("hidden", this.zoneOk)
    this.syncPayButton()
  }

  // --- email (guests only; logged-in email is read-only and already on the session) ---

  async emailChanged() {
    if (!this.guestValue) return
    const email = this.emailTarget.value.trim()
    if (!email) return
    try {
      const result = await this.actions.updateEmail(email)
      if (result?.error) return this.showError(result.error.message || "Please check your email address.")
      this.errorTarget.classList.add("hidden")
    } catch (error) {
      console.error("[onsite-checkout] updateEmail failed:", error)
      this.showError("Please check your email address.")
    }
  }

  // --- promo codes ---

  async applyPromo() {
    const code = this.promoInputTarget.value.trim()
    if (!code) return
    this.promoErrorTarget.classList.add("hidden")
    try {
      const result = await this.actions.applyPromotionCode(code)
      if (result?.error) throw result.error
    } catch (error) {
      this.promoErrorTarget.textContent = error?.message || "That code didn't work."
      this.promoErrorTarget.classList.remove("hidden")
      return
    }
    this.promoCodeTarget.textContent = code.toUpperCase()
    this.promoFormTarget.classList.add("hidden")
    this.promoAppliedTarget.classList.remove("hidden")
    this.promoAppliedTarget.classList.add("flex")
  }

  async removePromo() {
    try {
      const result = await this.actions.removePromotionCode()
      if (result?.error) throw result.error
    } catch (error) {
      console.error("[onsite-checkout] promo removal failed:", error)
      return
    }
    this.promoAppliedTarget.classList.add("hidden")
    this.promoAppliedTarget.classList.remove("flex")
    this.promoFormTarget.classList.remove("hidden")
    this.promoInputTarget.value = ""
  }

  // --- confirm ---

  async pay() {
    if (!this.zoneOk) return
    this.payButtonTarget.disabled = true
    this.errorTarget.classList.add("hidden")

    // On success Stripe redirects to return_url, so the button stays disabled;
    // any other outcome (a reported error OR a rejection, e.g. a network drop
    // mid-confirm) must surface a message and re-enable the button, or the
    // shopper is stuck on a dead Pay button.
    try {
      const result = await this.actions.confirm()
      if (!result?.error) return
      this.showError(result.error.message || "Payment failed. Please try again.")
    } catch (error) {
      console.error("[onsite-checkout] confirm failed:", error)
      this.showError("Payment couldn't be completed. Please check your connection and try again.")
    }
    this.syncPayButton()
  }

  // --- errors ---

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  fatal() {
    this.showError("Checkout couldn't load. Please refresh, or return to your basket and try again.")
  }
}
