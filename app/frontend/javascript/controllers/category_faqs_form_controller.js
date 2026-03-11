import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "hiddenInput"]
  static values = { faqs: Array }

  connect() {
    if (this.faqsValue.length === 0) return

    this.faqsValue.forEach(faq => this.addRow(faq.question, faq.answer))
  }

  add(event) {
    event.preventDefault()
    this.addRow("", "")
  }

  remove(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-faq-row]").remove()
    this.serialize()
  }

  serialize() {
    const rows = this.containerTarget.querySelectorAll("[data-faq-row]")
    const faqs = []

    rows.forEach(row => {
      const question = row.querySelector("[data-faq-question]").value.trim()
      const answer = row.querySelector("[data-faq-answer]").value.trim()

      if (question !== "" && answer !== "") {
        faqs.push({ question, answer })
      }
    })

    this.hiddenInputTarget.value = faqs.length > 0 ? JSON.stringify(faqs) : "[]"
  }

  addRow(question, answer) {
    const row = document.createElement("div")
    row.setAttribute("data-faq-row", "")
    row.className = "space-y-2 p-4 border border-base-300 rounded-lg"
    row.innerHTML = `
      <div class="flex items-center justify-between">
        <span class="text-sm text-base-content/60">FAQ Entry</span>
        <button type="button" class="btn btn-ghost btn-xs text-error"
                data-action="category-faqs-form#remove">Remove</button>
      </div>
      <input type="text" data-faq-question placeholder="Question"
             value="${this.escapeHtml(question)}"
             class="input input-bordered w-full"
             data-action="input->category-faqs-form#serialize">
      <textarea data-faq-answer placeholder="Answer"
                class="textarea textarea-bordered w-full" rows="2"
                data-action="input->category-faqs-form#serialize">${this.escapeHtml(answer)}</textarea>
    `
    this.containerTarget.appendChild(row)
    this.serialize()
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
