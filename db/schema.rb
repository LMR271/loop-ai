# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_16_193100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "feedbacks", force: :cascade do |t|
    t.string "conversation_id"
    t.datetime "created_at", null: false
    t.bigint "loop_id", null: false
    t.string "respondent_email"
    t.string "sentiment"
    t.text "sentiment_rationale"
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_feedbacks_on_conversation_id", unique: true
    t.index ["loop_id"], name: "index_feedbacks_on_loop_id"
  end

  create_table "insights", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "loop_id", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["loop_id"], name: "index_insights_on_loop_id"
  end

  create_table "loops", force: :cascade do |t|
    t.string "agent_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "logo_url"
    t.string "name"
    t.boolean "pending_approval", default: false, null: false
    t.string "slug"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["slug"], name: "index_loops_on_slug", unique: true
    t.index ["user_id"], name: "index_loops_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "loop_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["loop_id"], name: "index_questions_on_loop_id"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "account_owner_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_owner_id", "email"], name: "index_memberships_on_account_owner_id_and_email", unique: true
    t.index ["account_owner_id"], name: "index_memberships_on_account_owner_id"
    t.index ["invitation_token"], name: "index_memberships_on_invitation_token", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "dashboard_stat_keys"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "feedbacks", "loops"
  add_foreign_key "insights", "loops"
  add_foreign_key "loops", "users"
  add_foreign_key "questions", "loops"
  add_foreign_key "teams", "users"
  add_foreign_key "teams", "users", column: "account_owner_id"
end
