import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.sourceTarget.select()

    if (this.hasButtonTarget) {
      const icon = this.buttonTarget.querySelector("i")
      icon.classList.replace("fa-copy", "fa-check")
      setTimeout(() => icon.classList.replace("fa-check", "fa-copy"), 1500)
    }
  }
}
