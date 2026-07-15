import { Controller } from "@hotwired/stimulus"
import { Conversation } from "@elevenlabs/client"

// Drives the public respondent voice interview: fetches a signed URL from our
// server, then opens an ElevenLabs conversation. Every failure is surfaced in
// the status element so the respondent is never left staring at a dead button.
export default class extends Controller {
  static values = { slug: String }
  static targets = ["status", "startButton", "endButton"]

  async start() {
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
        onDisconnect: () => this.reset("Conversation ended."),
        onError: (message) => this.setStatus(`Error: ${message}`),
        onModeChange: ({ mode }) => this.setStatus(mode === "speaking" ? "Agent is speaking…" : "Listening…")
      })
    } catch (error) {
      this.reset(`Couldn't start the interview: ${error.message}`)
    }
  }

  async end() {
    this.setStatus("Ending…")
    try {
      await this.conversation?.endSession()
      // onDisconnect resets the UI; reset() here covers the no-session edge case.
    } catch (error) {
      this.reset(`Couldn't end cleanly: ${error.message}`)
    }
  }

  connected() {
    this.setStatus("Connected — start talking!")
    this.startButtonTarget.hidden = true
    this.endButtonTarget.hidden = false
  }

  reset(message) {
    this.setStatus(message)
    this.startButtonTarget.hidden = false
    this.startButtonTarget.disabled = false
    this.endButtonTarget.hidden = true
    this.conversation = null
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
