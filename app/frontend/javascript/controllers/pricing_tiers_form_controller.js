import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "hiddenInput"]
  static values = { tiers: Array }

  connect() {
    if (this.tiersValue.length === 0) return

    this.tiersValue
      .sort((a, b) => a.quantity - b.quantity)
      .forEach(tier => this.addRow(tier.quantity, tier.price))
  }

  add(event) {
    event.preventDefault()
    this.addRow("", "")
  }

  remove(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-tier-row]").remove()
    this.serialize()
  }

  serialize() {
    const rows = this.containerTarget.querySelectorAll("[data-tier-row]")
    const tiers = []

    rows.forEach(row => {
      const quantity = parseInt(row.querySelector("[data-tier-quantity]").value, 10)
      const price = row.querySelector("[data-tier-price]").value.trim()

      if (quantity > 0 && price !== "") {
        tiers.push({ quantity, price })
      }
    })

    this.hiddenInputTarget.value = tiers.length > 0 ? JSON.stringify(tiers) : ""
  }

  addRow(quantity, price) {
    const row = document.createElement("div")
    row.setAttribute("data-tier-row", "")
    row.className = "flex items-center gap-3 mb-2"
    row.innerHTML = `
      <input type="number" data-tier-quantity placeholder="Qty" value="${quantity}"
             class="input w-28" min="1" step="1"
             data-action="input->pricing-tiers-form#serialize">
      <input type="text" data-tier-price placeholder="Price (£)" value="${price}"
             class="input w-32"
             data-action="input->pricing-tiers-form#serialize">
      <button type="button" class="btn btn-ghost btn-sm text-error"
              data-action="pricing-tiers-form#remove">Remove</button>
    `
    this.containerTarget.appendChild(row)
    this.serialize()
  }
}
