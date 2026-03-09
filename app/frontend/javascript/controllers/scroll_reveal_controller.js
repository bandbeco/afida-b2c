import { Controller } from "@hotwired/stimulus"

/**
 * Scroll Reveal Controller
 * Applies a subtle fade-up animation when elements enter the viewport.
 * Animates once per element, does not repeat on scroll-back.
 *
 * Usage:
 *   <section data-controller="scroll-reveal">
 *     <div data-scroll-reveal-target="item">...</div>
 *     <div data-scroll-reveal-target="item">...</div>
 *   </section>
 *
 * Or animate the controller element itself (no targets needed):
 *   <section data-controller="scroll-reveal" data-scroll-reveal-self-value="true">...</section>
 *
 * Stagger delay between items (ms, default 80):
 *   data-scroll-reveal-stagger-value="100"
 *
 * Custom threshold (0-1, default 0.15):
 *   data-scroll-reveal-threshold-value="0.2"
 */
export default class extends Controller {
  static targets = ["item"]
  static values = {
    stagger: { type: Number, default: 80 },
    threshold: { type: Number, default: 0.15 },
    self: { type: Boolean, default: false }
  }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { threshold: this.thresholdValue, rootMargin: "0px 0px -40px 0px" }
    )

    if (this.selfValue) {
      this.element.classList.add("scroll-reveal-hidden")
      this.observer.observe(this.element)
    } else if (this.hasItemTarget) {
      this.itemTargets.forEach((item) => {
        item.classList.add("scroll-reveal-hidden")
        this.observer.observe(item)
      })
    } else {
      // No targets defined — animate direct children
      Array.from(this.element.children).forEach((child) => {
        child.classList.add("scroll-reveal-hidden")
        this.observer.observe(child)
      })
    }
  }

  handleIntersection(entries) {
    // Group entries that became visible in this callback
    const revealed = entries.filter((entry) => entry.isIntersecting)

    revealed.forEach((entry, index) => {
      const delay = index * this.staggerValue

      setTimeout(() => {
        entry.target.classList.remove("scroll-reveal-hidden")
        entry.target.classList.add("scroll-reveal-visible")
        this.observer.unobserve(entry.target)
      }, delay)
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
