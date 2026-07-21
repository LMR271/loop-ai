require "test_helper"

class InsightTest < ActiveSupport::TestCase
  test "loop_id is unique at the database level" do
    user = User.create!(email: "founder5@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user)
    loop_record.create_insight!

    assert_raises(ActiveRecord::RecordNotUnique) { Insight.create!(loop: loop_record) }
  end
end
