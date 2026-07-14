import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "customField"]

  toggle() {
    const isCustom = this.selectTarget.value === "custom"
    this.customFieldTargets.forEach((field) => field.classList.toggle("d-none", !isCustom))

    if (!isCustom) {
      this.element.requestSubmit()
    }
  }
}
