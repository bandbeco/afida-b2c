import { Controller } from "@hotwired/stimulus"
import { gsap } from "gsap"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.slideInFromTop()
  }

  slideInFromTop() {
    // Staggered slide-in animation from top on page load
    gsap.from(this.itemTargets, {
      y: -30,
      opacity: 0,
      duration: 0.8,
      ease: "power2.out",
      delay: 0.3,
      stagger: 0.15
    })
  }
}

