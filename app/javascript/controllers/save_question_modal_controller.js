import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "error"]

  connect() {
    this.boundSubmitEnd = this.submitEnd.bind(this)
    this.formTarget.addEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  disconnect() {
    this.formTarget.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  submitEnd(event) {
    if (!event.detail.success) return

    this.formTarget.reset()
    this.errorTarget.classList.add("d-none")

    bootstrap.Modal.getOrCreateInstance(this.element).hide()
  }
}
