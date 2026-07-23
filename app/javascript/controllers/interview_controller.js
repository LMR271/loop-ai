import { Controller } from "@hotwired/stimulus"
import { Conversation } from "@elevenlabs/client"

// Drives the public respondent voice interview: fetches a signed URL from our
// server, opens an ElevenLabs conversation, and mirrors the live call state
// onto the orb. Every failure is surfaced in the aria-live status element so
// the respondent is never left staring at a dead orb.
export default class extends Controller {
  static values = { slug: String }
  static targets = ["status", "startButton", "endButton", "orb", "thankYou", "consentCheckbox"]

  static STATES = ["is-idle", "is-connecting", "is-listening", "is-speaking", "is-ended"]

  connect() {
    this.toggleConsent()
  }

  toggleConsent() {
    if (this.hasConsentCheckboxTarget) this.startButtonTarget.disabled = !this.consentCheckboxTarget.checked
  }

  async start() {
    this.setOrbState("is-connecting")
    this.setStatus("Connecting…")
    this.startButtonTarget.disabled = true

    try {
      const res = await fetch(`/i/${this.slugValue}/signed_url`)
      if (!res.ok) throw new Error(`server responded ${res.status} when requesting a signed URL`)

      const { signed_url: signedUrl } = await res.json()
      if (!signedUrl) throw new Error("the server did not return a signed URL")

      this.conversation = await Conversation.startSession({
        signedUrl,
        onConnect: () => this.connected(),
        onDisconnect: () => this.finished(),
        onError: (message) => this.setStatus(`Error: ${message}`),
        onModeChange: ({ mode }) => this.modeChanged(mode)
      })
    } catch (error) {
      this.failedToStart(`Couldn't start the interview: ${error.message}`)
    }
  }

  async end() {
    this.setStatus("Ending…")
    try {
      await this.conversation?.endSession()
      // onDisconnect → finished() resets the UI; finished() here covers no-session.
    } catch (error) {
      this.setStatus(`Couldn't end cleanly: ${error.message}`)
    }
  }

  connected() {
    this.setOrbState("is-listening")
    this.setStatus("Connected — start talking!")
    this.startButtonTarget.hidden = true
    this.endButtonTarget.hidden = false
  }

  modeChanged(mode) {
    if (mode === "speaking") {
      this.setOrbState("is-speaking")
      this.setStatus("Agent is speaking…")
    } else {
      this.setOrbState("is-listening")
      this.setStatus("Listening…")
    }
  }

  finished() {
    if (!this.conversation) return
      this.conversation = null
      this.setOrbState("is-ended")
      this.setStatus("")
      this.startButtonTarget.hidden = true
      this.endButtonTarget.hidden = true
    if (this.hasThankYouTarget) this.thankYouTarget.hidden = false
  }

  // start() failed before/while connecting: return to idle, keep Start available.
  failedToStart(message) {
    this.conversation = null
    this.setOrbState("is-idle")
    this.setStatus(message)
    this.startButtonTarget.hidden = false
    this.startButtonTarget.disabled = false
    this.endButtonTarget.hidden = true
  }

  setOrbState(state) {
    if (!this.hasOrbTarget) return
    this.orbTarget.classList.remove(...this.constructor.STATES)
    this.orbTarget.classList.add(state)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
