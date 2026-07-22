# Receives finished conversations from ElevenLabs and records them as Feedback.
#
# The webhook is registered once, workspace-wide — every agent's transcripts arrive
# here. ElevenLabs disables a webhook after 10 consecutive failures, which would kill
# ingestion for EVERY loop, and failed deliveries are never retried. So: always 200,
# except for a request we can't authenticate. Anything we can't use is logged, not
# rejected.
class ElevenLabsWebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection
  before_action :verify_signature

  def create
    return head :ok unless payload.transcription?

    record_feedback
    head :ok
  end

  private

  def payload
    @payload ||= ElevenLabsWebhookPayload.new(request.raw_post)
  end

  # The only non-200: an unsigned or forged request is not ElevenLabs, so it doesn't
  # count against the workspace webhook's failure budget.
  def verify_signature
    return if ElevenLabsSignatureVerifier.new(
      request.headers["ElevenLabs-Signature"], request.raw_post
    ).valid?

    Rails.logger.warn("[ElevenLabs] rejected webhook with an invalid signature")
    head :unauthorized
  end

  def record_feedback
    loop_record = Loop.find_by(agent_id: payload.agent_id)
    return Rails.logger.warn("[ElevenLabs] no loop for agent #{payload.agent_id}") if loop_record.nil?

    create_feedback(loop_record)
  end

  # The unique index on conversation_id — not this rescue — is what guarantees
  # idempotency: two simultaneous deliveries would both pass an exists? check.
  def create_feedback(loop_record)
    feedback = Feedback.create!(feedback_attributes.merge(loop: loop_record))
    LoopMailer.new_feedback(feedback).deliver_later
    AnalyzeFeedbackJob.perform_later(feedback)
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("[ElevenLabs] already recorded conversation #{payload.conversation_id}")
  end

  def feedback_attributes
    {
      conversation_id: payload.conversation_id,
      transcript: payload.transcript,
      sentiment: payload.sentiment,
      sentiment_rationale: payload.sentiment_rationale,
      title: payload.summary_title,
      summary: payload.transcript_summary
    }
  end
end
