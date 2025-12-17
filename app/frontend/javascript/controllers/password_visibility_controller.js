import { Controller } from "@hotwired/stimulus"

/**
 * Password Visibility Toggle Controller
 *
 * Toggles password field between hidden (•••) and visible (text) states.
 * Provides better UX than password confirmation fields.
 *
 * Usage:
 *   <div data-controller="password-visibility">
 *     <input type="password" data-password-visibility-target="input">
 *     <button type="button" data-action="password-visibility#toggle">
 *       <span data-password-visibility-target="showIcon">👁</span>
 *       <span data-password-visibility-target="hideIcon" class="hidden">👁‍🗨</span>
 *     </button>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "showIcon", "hideIcon"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"

    this.inputTarget.type = isPassword ? "text" : "password"

    if (this.hasShowIconTarget && this.hasHideIconTarget) {
      this.showIconTarget.classList.toggle("hidden", !isPassword)
      this.hideIconTarget.classList.toggle("hidden", isPassword)
    }
  }
}
