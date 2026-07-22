import { Controller } from "@hotwired/stimulus"

// Lower = softer/slower easing toward the cursor each frame.
const EASE = 0.025

// Orb eases toward the cursor and holds position on pointerleave (no reset).
export default class extends Controller {
  static targets = ["orb"]

  connect() {
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.reducedMotion) return

    this.targetX = 0
    this.targetY = 0
    this.currentX = 0
    this.currentY = 0

    this.handleMove = this.handleMove.bind(this)
    this.tick = this.tick.bind(this)

    this.element.addEventListener("pointermove", this.handleMove)
    this.frame = requestAnimationFrame(this.tick)
  }

  disconnect() {
    this.element.removeEventListener("pointermove", this.handleMove)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  handleMove(event) {
    const rect = this.element.getBoundingClientRect()
    this.targetX = event.clientX - rect.left - rect.width / 2
    this.targetY = event.clientY - rect.top - rect.height / 2
  }

  tick() {
    this.currentX += (this.targetX - this.currentX) * EASE
    this.currentY += (this.targetY - this.currentY) * EASE

    this.orbTarget.style.setProperty("--posX", this.currentX)
    this.orbTarget.style.setProperty("--posY", this.currentY)

    this.frame = requestAnimationFrame(this.tick)
  }
}
