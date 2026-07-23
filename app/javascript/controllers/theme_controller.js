import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    this.render(this.currentTheme)
  }

  get currentTheme() {
    return document.documentElement.getAttribute("data-bs-theme") || "light"
  }

  toggle() {
    const next = this.currentTheme === "dark" ? "light" : "dark"
    document.documentElement.setAttribute("data-bs-theme", next)
    localStorage.setItem("theme", next)
    this.render(next)
  }

  // Shows what clicking will switch TO, not the current theme.
  render(theme) {
    const target = theme === "dark" ? "light" : "dark"
    this.iconTarget.classList.toggle("fa-sun", target === "light")
    this.iconTarget.classList.toggle("fa-moon", target === "dark")
    this.labelTarget.textContent = target === "dark" ? "Dark mode" : "Light mode"
  }
}
