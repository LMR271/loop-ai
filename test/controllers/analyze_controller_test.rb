require "test_helper"

class AnalyzeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "refresh enqueues the loop analysis" do
    loop_record = @user.loops.create!(name: "L")
    assert_enqueued_with(job: AnalyzeLoopJob) do
      post refresh_analyze_path(loop_record.slug)
    end
    assert_redirected_to analyze_path(loop_record.slug)
  end

  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive",
                                          analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-card", text: /Going well/
    assert_select ".analysis-card", text: /Onboarding overwhelming/
  end

  test "a loop with no feedback ever shows one unified empty state instead of scattered empty boxes" do
    loop_record = @user.loops.create!(name: "L")

    get analyze_path(loop_record.slug)

    assert_select "#per-loop-pane" do
      assert_select ".loops-empty-state", text: /No feedback yet/
      assert_select ".analysis-stat-row", count: 0
      assert_select ".analysis-card", count: 0
    end
  end

  test "backfill enqueues one Stage 1 job per pending feedback" do
    loop_record = analysable_loop_with_points
    Feedback.create!(loop: loop_record, transcript: "unanalyzed one")

    assert_enqueued_jobs 1, only: AnalyzeFeedbackJob do
      post backfill_analyze_path(loop_record.slug)
    end
    assert_redirected_to analyze_path(loop_record.slug)
  end

  test "overview shows a live stat row with response, theme, and feature request counts" do
    loop_record = @user.loops.create!(name: "L")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "T1", mention_count: 1, sentiment: "positive")
    loop_record.feedbacks.create!(transcript: "hi one")
    loop_record.feedbacks.create!(transcript: "hi two")

    get analyze_path(loop_record.slug)

    values = css_select(".analysis-stat-row dd").map(&:text)
    assert_equal ["2", "1", "0"], values[0..2]
    assert_match(/Positive/, values[3])
  end

  test "insight card explains that the summary is AI-generated from every transcript" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-card", text: /Summary of all feedback/
    assert_select ".analysis-card", text: /AI-generated from every interview transcript/
  end

  test "themes and feature requests sections show a scoped empty state when the insight has neither" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    loop_record.create_insight!(summary: "S", overall_sentiment: "neutral", analyzed_feedback_count: 1)

    get analyze_path(loop_record.slug)

    assert_select ".analysis-section-empty", text: /No themes yet/
    assert_select ".analysis-section-empty", text: /No feature requests surfaced yet/
  end

  test "response cards label the AI-generated summary and use the shared card style" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "raw words", title: "Title", summary: "Generated summary")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-response-card", text: /AI summary/
    assert_select ".analysis-response-card", text: /Generated summary/
  end

  test "the pending-analysis nudge renders inline, not inside the flash toast container" do
    loop_record = analysable_loop_with_points
    loop_record.feedbacks.create!(transcript: "no points yet")

    get analyze_path(loop_record.slug)

    assert_select ".alert-warning", text: /haven.t been analyzed yet/
    assert_select ".flash-toast-container .alert-warning", count: 0
  end

  test "flash notices render inside a dedicated toast container" do
    loop_record = @user.loops.create!(name: "L")

    post refresh_analyze_path(loop_record.slug)
    follow_redirect!

    assert_select ".flash-toast-container .alert", text: /analysis started/i
  end

  test "visiting a loop's analyse page stamps the current user's last-seen feedback count" do
    loop_record = @user.loops.create!(name: "L")
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }

    get analyze_path(loop_record.slug)

    loop_view = @user.loop_views.find_by(loop: loop_record)
    assert_equal 2, loop_view.last_seen_feedback_count
  end

  test "visiting a loop with no feedback yet does not create a loop_view row" do
    loop_record = @user.loops.create!(name: "L")

    get analyze_path(loop_record.slug)

    assert_nil @user.loop_views.find_by(loop: loop_record)
  end

  test "visiting a loop again without new feedback does not regress last_seen_feedback_count" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyze_path(loop_record.slug)
    loop_view = @user.loop_views.find_by(loop: loop_record)
    loop_view.update!(last_seen_feedback_count: 5)

    get analyze_path(loop_record.slug)

    assert_equal 5, loop_view.reload.last_seen_feedback_count
  end

  test "one teammate viewing a loop does not clear the notification for another teammate" do
    teammate = User.create!(email: "teammate@example.com", password: "password123")
    @user.team_memberships.create!(email: teammate.email, role: :editor, user: teammate,
                                   invitation_accepted_at: Time.current)
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyze_path(loop_record.slug)

    sign_out @user
    sign_in teammate
    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "1"
  end

  test "response cards are anchored by feedback id so interview links can jump to them" do
    loop_record = @user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi")

    get analyze_path(loop_record.slug)

    assert_select "#feedback-#{feedback.id}"
  end

  test "interview numbers are assigned oldest-first across the loop's full history, ignoring the range filter" do
    loop_record = @user.loops.create!(name: "L")
    older = loop_record.feedbacks.create!(transcript: "old one", created_at: 40.days.ago)
    newer = loop_record.feedbacks.create!(transcript: "new one", created_at: 1.day.ago)
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 2)
    theme = insight.themes.create!(title: "T1", mention_count: 2, sentiment: "positive")
    theme.quotes.create!(feedback: older, text: "old quote")
    theme.quotes.create!(feedback: newer, text: "new quote")

    # default range is 30 days, so `older` (40 days ago) would be excluded from "Every response"
    # if numbering were computed off the range-scoped @feedbacks instead of the full history.
    get analyze_path(loop_record.slug)

    assert_select ".analysis-quote-tag", text: /Interview #1/
    assert_select ".analysis-quote-tag", text: /Interview #2/
  end

  private

  def analysable_loop_with_points
    loop_record = @user.loops.create!(name: "L")
    points = { "points" => [{ "kind" => "theme", "title" => "t", "quote" => "q" }] }
    loop_record.feedbacks.create!(transcript: "hi", extracted_points: points)
    loop_record
  end
end
