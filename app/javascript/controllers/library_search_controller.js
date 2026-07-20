import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "group", "entry", "empty"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let matches = 0

    this.groupTargets.forEach((group) => {
      const categoryMatches = group.dataset.librarySearchCategory.includes(query)
      let visibleEntries = 0

      group.querySelectorAll("[data-library-search-target='entry']").forEach((entry) => {
        const matchesEntry = categoryMatches || entry.dataset.librarySearchContent.includes(query)
        entry.hidden = !matchesEntry
        if (matchesEntry) visibleEntries += 1
      })

      group.hidden = visibleEntries === 0
      matches += visibleEntries
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("d-none", matches > 0)
  }
}
