import { Controller } from "@hotwired/stimulus"
import "bootstrap"

export default class extends Controller {
  // Submitting the form redirects via Turbo, which can outrun Bootstrap's own
  // transition-based cleanup — hide the modal explicitly so its backdrop and
  // body styles are removed instead of lingering until a manual refresh.
  hide(event) {
    if (!event.detail.success) return

    window.bootstrap.Modal.getOrCreateInstance(this.element).hide()
  }
}
