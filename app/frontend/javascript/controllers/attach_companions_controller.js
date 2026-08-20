import { Controller } from "@hotwired/stimulus"

/**
 * Attach Companions Controller
 *
 * The compatible-products block inside the add-to-cart form. Ticking a row
 * enables its quantity select (an unticked row must contribute nothing to the
 * submission) and seeds that quantity from the product's own quantity, since
 * pack counts usually mirror each other. The seed happens once, at tick time:
 * the buyer can then set any number without it being overwritten later.
 *
 * Selection changes are announced so the buy box's total can include them.
 *
 * Targets:
 * - checkbox: One per companion row
 * - quantity: The pack-count select beside each checkbox
 * - hiddenRow: Rows folded away behind the disclosure
 * - disclosure: The "show all" button
 */
export default class extends Controller {
  static targets = ["checkbox", "quantity", "hiddenRow", "disclosure"]

  connect() {
    this.announce()
  }

  toggle(event) {
    const row = event.target.closest("[data-test='attach-row']")
    if (!row) return

    const checkbox = row.querySelector("input[type=checkbox]")
    const quantity = row.querySelector("select")

    if (checkbox && quantity) {
      quantity.disabled = !checkbox.checked
      if (checkbox.checked && event.target === checkbox) {
        quantity.value = this.matchingQuantity(quantity)
      }
    }

    this.announce()
  }

  showAll() {
    this.hiddenRowTargets.forEach(row => row.classList.remove("hidden"))
    if (this.hasDisclosureTarget) this.disclosureTarget.classList.add("hidden")
  }

  // The product's own quantity, if the select offers it. Buyers who want ten
  // trays almost always want ten packs of lids, so that is where the row opens.
  matchingQuantity(select) {
    const primary = document.getElementById("quantity")
    const wanted = primary ? parseInt(primary.value, 10) : 1
    if (!wanted || wanted < 1) return select.value

    const offered = Array.from(select.options).map(option => option.value)
    return offered.includes(String(wanted)) ? String(wanted) : select.value
  }

  // Selected companions as {price, quantity}, for whoever is summing the total.
  get selection() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => {
        const row = checkbox.closest("[data-test='attach-row']")
        const quantity = row ? row.querySelector("select") : null
        return {
          price: parseFloat(checkbox.dataset.companionPrice) || 0,
          quantity: quantity ? parseInt(quantity.value, 10) || 1 : 1
        }
      })
  }

  announce() {
    const total = this.selection.reduce((sum, item) => sum + item.price * item.quantity, 0)
    this.dispatch("changed", { detail: { total }, prefix: "attach-companions" })
  }
}
