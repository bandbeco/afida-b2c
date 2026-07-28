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
    "email", "address", "payment", "payButton", "error",
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
        defaultValues: this.defaultValues()
      })
      this.actions = await this.checkout.loadActions()
    } catch (error) {
      console.error("[onsite-checkout] init failed:", error)
      return this.fatal()
    }

    this.checkout.createPaymentElement().mount(this.paymentTarget)
    this.checkout.createShippingAddressElement().mount(this.addressTarget)

    this.checkout.on("change", (session) => this.sessionChanged(session))
    this.sessionChanged(this.actions.getSession())
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
    try {
      const response = await fetch(`/shipping_zone?postcode=${encodeURIComponent(postcode)}`)
      if (!response.ok) return
      const { zone } = await response.json()
      this.zoneOk = zone === this.pricedZoneValue
    } catch {
      this.zoneOk = true // fail open: no worse than hosted checkout today
    }
    this.zoneWarningTarget.classList.toggle("hidden", this.zoneOk)
    this.syncPayButton()
  }

  // --- email (guests only; logged-in email is read-only and already on the session) ---

  async emailChanged() {
    if (!this.guestValue) return
    const email = this.emailTarget.value.trim()
    if (!email) return
    try {
      await this.actions.updateEmail(email)
    } catch {
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
      await this.actions.removePromotionCode()
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

    // On success Stripe redirects to return_url; we only come back on error.
    const result = await this.actions.confirm()
    if (result?.error) {
      this.showError(result.error.message || "Payment failed. Please try again.")
      this.syncPayButton()
    }
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
