require "test_helper"

class AnalyseControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "refresh enqueues the loop analysis" do
    loop_record = @user.loops.create!(name: "L")
    assert_enqueued_with(job: AnalyzeLoopJob) do
      post refresh_analyse_path(loop_record.slug)
    end
    assert_redirected_to analyse_path(loop_record.slug)
  end
end
