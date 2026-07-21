import { Controller } from "@hotwired/stimulus"
import "bootstrap"

export default class extends Controller {
  connect() {
    this.tooltip = new window.bootstrap.Tooltip(this.element)
  }

  disconnect() {
    this.tooltip.dispose()
  }
}
