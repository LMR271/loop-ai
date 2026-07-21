// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"
import "Chart.bundle"
import "chartkick"

// Canvas charts cannot consume CSS custom properties directly. Read the
// theme token once so Chartkick remains aligned with the application palette.
window.Chartkick.options = {
  colors: [getComputedStyle(document.documentElement).getPropertyValue("--color-primary").trim()]
}
