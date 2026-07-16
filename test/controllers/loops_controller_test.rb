require "test_helper"

class LoopsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "index only shows the signed-in user's loops" do
    own_loop = @user.loops.create!(name: "Customer interviews")
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_user.loops.create!(name: "Private loop")

    get loops_path

    assert_response :success
    assert_select "h2", text: own_loop.name
    assert_select "h2", text: "Private loop", count: 0
    assert_select "a[href='#{new_loop_path}']", text: "New Loop", count: 2
  end

  test "index searches the signed-in user's loops by name and description" do
    matching_loop = @user.loops.create!(name: "Onboarding interviews", description: "New user experience")
    @user.loops.create!(name: "Pricing research", description: "Subscription plans")
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_user.loops.create!(name: "Private onboarding", description: "Must not be searchable")

    get loops_path, params: { q: "onboard" }

    assert_response :success
    assert_select "h2", text: matching_loop.name
    assert_select "h2", text: "Pricing research", count: 0
    assert_select "h2", text: "Private onboarding", count: 0
    assert_select "input[name='q'][value='onboard']", count: 1
  end

  test "deleting a loop also deletes its associated records" do
    loop = @user.loops.create!(name: "Old research")
    loop.feedbacks.create!(transcript: "A response")
    loop.questions.create!(body: "What helped?")
    loop.create_insight!(summary: "Useful")

    assert_difference("Loop.count", -1) do
      delete loop_path(loop)
    end

    assert_redirected_to loops_path
    assert_equal 0, Feedback.where(loop_id: loop.id).count
    assert_equal 0, Question.where(loop_id: loop.id).count
    assert_equal 0, Insight.where(loop_id: loop.id).count
  end

  test "a user cannot delete another user's loop" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_loop = other_user.loops.create!(name: "Private loop")

    assert_no_difference("Loop.count") do
      delete loop_path(other_loop)
    end

    assert_response :not_found
  end

  test "founder can create a loop with questions" do
    assert_difference(["Loop.count", "Question.count"], 1) do
      post loops_path, params: {
        loop: {
          name: "Onboarding research",
          description: "Learn where new customers get stuck.",
          questions_attributes: {
            "0" => { body: "What did you expect when you signed up?", position: 1 }
          }
        }
      }
    end

    loop = @user.loops.find_by!(name: "Onboarding research")
    assert_redirected_to dashboard_path
    assert_equal "What did you expect when you signed up?", loop.questions.first.body
  end

  test "founder can edit, remove, add, and reorder questions" do
    loop = @user.loops.create!(name: "Existing research")
    first = loop.questions.create!(body: "First question", position: 1)
    second = loop.questions.create!(body: "Second question", position: 2)

    patch loop_path(loop), params: {
      loop: {
        name: "Updated research",
        questions_attributes: {
          "0" => { id: first.id, body: "First question, revised", position: 2 },
          "1" => { id: second.id, _destroy: "1" },
          "2" => { body: "New first question", position: 1 }
        }
      }
    }

    assert_redirected_to edit_loop_path(loop)
    assert_equal "Updated research", loop.reload.name
    assert_equal ["New first question", "First question, revised"], loop.questions.pluck(:body)
    assert_equal [1, 2], loop.questions.pluck(:position)
  end

  test "founder cannot edit another user's loop" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_loop = other_user.loops.create!(name: "Private research")

    get edit_loop_path(other_loop)

    assert_response :not_found
  end

  test "activating a draft loop with questions provisions an agent and marks it active" do
    loop = @user.loops.create!(name: "Ready to launch")
    loop.questions.create!(body: "What did you think?", position: 1)

    stub_instance_method(ElevenLabsAgentCreator, :call, ->(*) { "agent_test_123" }) do
      post activate_loop_path(loop)
    end

    assert_redirected_to edit_loop_path(loop)
    loop.reload
    assert loop.active?
    assert_equal "agent_test_123", loop.agent_id
  end

  test "activating a loop with no questions is blocked and makes no API call" do
    loop = @user.loops.create!(name: "No questions yet")
    called = false

    stub_instance_method(ElevenLabsAgentCreator, :call, ->(*) { called = true }) do
      post activate_loop_path(loop)
    end

    assert_not called, "should not create an agent"
    assert_redirected_to edit_loop_path(loop)
    loop.reload
    assert loop.draft?
    assert_nil loop.agent_id
  end

  test "activating an already-active loop does not create a second agent" do
    loop = @user.loops.create!(name: "Already live", status: :active, agent_id: "existing_agent")
    loop.questions.create!(body: "Still here?", position: 1)
    called = false

    stub_instance_method(ElevenLabsAgentCreator, :call, ->(*) { called = true }) do
      post activate_loop_path(loop)
    end

    assert_not called, "should not create a second agent"
    assert_redirected_to edit_loop_path(loop)
    assert_equal "existing_agent", loop.reload.agent_id
  end

  test "a failed agent creation leaves the loop draft with an error flash" do
    loop = @user.loops.create!(name: "Will fail")
    loop.questions.create!(body: "Anything?", position: 1)
    failing = ->(*) { raise ElevenLabsAgentCreator::Error, "boom" }

    stub_instance_method(ElevenLabsAgentCreator, :call, failing) do
      post activate_loop_path(loop)
    end

    assert_redirected_to edit_loop_path(loop)
    assert_match(/Couldn't create agent/, flash[:alert])
    loop.reload
    assert loop.draft?
    assert_nil loop.agent_id
  end
end
