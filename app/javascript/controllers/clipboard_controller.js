import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  connect() {
    this.boundResize = this.resizeSource.bind(this)

    // The card usually sits inside a Bootstrap modal, which is display:none
    // until shown — scrollHeight reads as 0 until then, so size once it opens.
    this.modal = this.element.closest(".modal")
    if (this.modal) {
      this.modal.addEventListener("shown.bs.modal", this.boundResize)
    } else {
      this.resizeSource()
    }
  }

  disconnect() {
    if (this.modal) this.modal.removeEventListener("shown.bs.modal", this.boundResize)
  }

  resizeSource() {
    if (this.sourceTarget.tagName !== "TEXTAREA") return

    this.sourceTarget.style.height = "auto"
    this.sourceTarget.style.height = `${this.sourceTarget.scrollHeight}px`
  }

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
