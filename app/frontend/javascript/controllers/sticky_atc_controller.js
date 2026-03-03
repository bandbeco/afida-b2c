import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mainButton", "stickyBar"]

  connect() {
    if (window.innerWidth >= 768) return

    this.setupIntersectionObserver()
    this.setupMutationObserver()
  }

  disconnect() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }
  }

  setupIntersectionObserver() {
    this.intersectionObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.hideStickyBar()
          } else {
            this.showStickyBar()
          }
        })
      },
      { threshold: 0 }
    )

    this.mainButtonTargets.forEach((button) => {
      this.intersectionObserver.observe(button)
    })
  }

  setupMutationObserver() {
    this.mutationObserver = new MutationObserver(() => {
      this.syncDisabledState()
    })

    this.mainButtonTargets.forEach((button) => {
      this.mutationObserver.observe(button, {
        attributes: true,
        attributeFilter: ["disabled"]
      })
    })

    this.syncDisabledState()
  }

  syncDisabledState() {
    if (!this.hasStickyBarTarget) return

    const stickyButton = this.stickyBarTarget.querySelector("button[type='submit']")
    if (!stickyButton) return

    const anyDisabled = this.mainButtonTargets.some((btn) => btn.disabled)
    stickyButton.disabled = anyDisabled
  }

  showStickyBar() {
    if (!this.hasStickyBarTarget) return
    this.stickyBarTarget.classList.remove("translate-y-full")
    this.stickyBarTarget.classList.add("translate-y-0")
  }

  hideStickyBar() {
    if (!this.hasStickyBarTarget) return
    this.stickyBarTarget.classList.add("translate-y-full")
    this.stickyBarTarget.classList.remove("translate-y-0")
  }
}
