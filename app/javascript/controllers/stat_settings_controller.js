import { Controller } from "@hotwired/stimulus"

const MAX_SELECTED = 4

export default class extends Controller {
  static targets = ["item", "checkbox"]

  connect() {
    this.limitSelection()
  }

  dragStart(event) {
    this.draggedItem = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
  }

  dragOver(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!this.draggedItem || target === this.draggedItem) return

    const rect = target.getBoundingClientRect()
    const before = (event.clientY - rect.top) < rect.height / 2
    target.parentNode.insertBefore(this.draggedItem, before ? target : target.nextSibling)
  }

  dragEnd() {
    this.draggedItem = null
  }

  limitSelection() {
    const checkedCount = this.checkboxTargets.filter((box) => box.checked).length

    this.checkboxTargets.forEach((box) => {
      box.disabled = !box.checked && checkedCount >= MAX_SELECTED
    })
  }
}
