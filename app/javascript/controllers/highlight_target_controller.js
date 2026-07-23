import { Controller } from "@hotwired/stimulus"

// Jumps to and highlights whatever #fragment the page loaded with — either a feedback
// card (interview links) or a theme/feature-request tile anchor (extracted-point badges).
// Runs on connect (page loads / Turbo visits) and on hashchange (same-page anchor clicks,
// e.g. the extracted-point badges which use turbo: false and never trigger a Turbo visit).
export default class extends Controller {
  connect() {
    this.highlight()
  }

  highlight() {
    if (!window.location.hash) return

    const target = document.getElementById(window.location.hash.slice(1))
    if (!target) return

    const tile = target.closest(".analysis-tile, .analysis-response-card") || target
    if (tile.tagName === "DETAILS") tile.open = true

    tile.classList.remove("analysis-highlight")
    void tile.offsetWidth // restart the CSS animation if the same tile is targeted twice in a row
    tile.classList.add("analysis-highlight")

    tile.scrollIntoView({ behavior: "smooth", block: "center" })
  }
}
