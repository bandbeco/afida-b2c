import { Controller } from "@hotwired/stimulus"

// On-site checkout: binds the page to a Stripe Checkout Session (ui_mode:
// "custom") created server-side. Stripe's SDK owns the money math; this
// controller mounts the secure elements, mirrors session totals into the
// summary, applies/removes promo codes, guards the shipping zone, and
// confirms. API per https://docs.stripe.com/js/custom_checkout.
//
// Money lines: only total, VAT, and discount re-render from the SDK. The goods
// subtotal and shipping lines stay server-rendered on purpose - shipping rides
// as a Stripe LINE ITEM (see Checkout::SessionBuilder), so the SDK's
// session.total.subtotal INCLUDES shipping and would mislabel our goods-only
// "Subtotal" row. Neither can change on-page in v1 (no cart editing, no
// shipping choice); only a promo code moves money, and that moves exactly
// discount, VAT, and total.
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
    this.payButtonTarget.disabled = !this.zoneOk || this.session?.canConfirm === false
  }

  // --- zone guard (best-effort; any failure fails open) ---

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
