// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"
import "Chart.bundle"
import "chartkick"

// Canvas charts cannot consume CSS custom properties directly. Read the
// theme tokens once so Chartkick remains aligned with the application palette.
const chartStyle = getComputedStyle(document.documentElement)
const chartAccent = chartStyle.getPropertyValue("--color-accent").trim()
const chartMutedText = chartStyle.getPropertyValue("--color-text-muted").trim()
const chartGridline = chartStyle.getPropertyValue("--color-border").trim()

window.Chartkick.options = {
  colors: [chartAccent],
  library: {
    elements: {
      bar: { borderRadius: 4, borderSkipped: false },
      line: { borderWidth: 2, tension: 0.35 },
      point: { radius: 0, hoverRadius: 4, hitRadius: 8 }
    },
    datasets: {
      bar: { categoryPercentage: 0.6, barPercentage: 0.8 }
    },
    scales: {
      x: {
        grid: { display: false },
        border: { display: false },
        ticks: { color: chartMutedText }
      },
      y: {
        grid: { color: chartGridline, drawTicks: false, borderDash: [4, 4] },
        border: { display: false },
        ticks: { color: chartMutedText, padding: 8 }
      }
    }
  }
}
