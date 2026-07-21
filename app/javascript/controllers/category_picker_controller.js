import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "field", "input"]

  toggle() {
    const creatingNew =
      this.selectTarget.value === "__create_new_category__"

    this.fieldTarget.classList.toggle("d-none", !creatingNew)

    if (creatingNew) {
      this.inputTarget.focus()
    } else {
      this.inputTarget.value = ""
    }
  }

  submit(event) {
    if (this.selectTarget.value !== "__create_new_category__") return

    const name = this.inputTarget.value.trim()

    if (name === "") {
      event.preventDefault()
      this.inputTarget.focus()
      return
    }

    this.selectTarget.innerHTML += `<option value="${name}" selected>${name}</option>`
    this.selectTarget.value = name
  }
}
