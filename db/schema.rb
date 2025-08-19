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

ActiveRecord::Schema[8.0].define(version: 2025_08_13_132123) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "matches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "target_id", null: false
    t.string "action_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "swiped_at"
    t.bigint "team_id"
    t.text "invitation_message"
    t.text "project_context"
    t.string "status", default: "pending"
    t.index ["action_type"], name: "index_matches_on_action_type"
    t.index ["status"], name: "index_matches_on_status"
    t.index ["target_id"], name: "index_matches_on_target_id"
    t.index ["team_id"], name: "index_matches_on_team_id"
    t.index ["user_id"], name: "index_matches_on_user_id"
  end

  create_table "targets", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "team_id", null: false
    t.string "role", default: "member"
    t.string "status", default: "active"
    t.datetime "joined_at", null: false
    t.text "contribution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role"], name: "index_team_memberships_on_role"
    t.index ["status"], name: "index_team_memberships_on_status"
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_team_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "project_type"
    t.string "status", default: "forming"
    t.integer "max_members", default: 5
    t.bigint "creator_id", null: false
    t.string "university"
    t.text "required_skills", default: [], array: true
    t.text "tags", default: [], array: true
    t.datetime "project_deadline"
    t.string "meeting_schedule"
    t.text "communication_channels", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_teams_on_creator_id"
    t.index ["project_type"], name: "index_teams_on_project_type"
    t.index ["required_skills"], name: "index_teams_on_required_skills", using: :gin
    t.index ["status"], name: "index_teams_on_status"
    t.index ["tags"], name: "index_teams_on_tags", using: :gin
    t.index ["university"], name: "index_teams_on_university"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role"
    t.text "skills"
    t.text "bio"
    t.string "university"
    t.string "degree_program"
    t.integer "year_of_study"
    t.text "availability"
    t.text "preferred_project_types", default: [], array: true
    t.boolean "looking_for_teammates", default: true
    t.boolean "hide_last_name", default: false
    t.string "github_username"
    t.string "linkedin_url"
    t.string "portfolio_url"
    t.string "timezone"
    t.text "communication_preferences", default: [], array: true
    t.index ["degree_program"], name: "index_users_on_degree_program"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["looking_for_teammates"], name: "index_users_on_looking_for_teammates"
    t.index ["preferred_project_types"], name: "index_users_on_preferred_project_types", using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["university"], name: "index_users_on_university"
    t.index ["year_of_study"], name: "index_users_on_year_of_study"
  end

  add_foreign_key "matches", "teams"
  add_foreign_key "matches", "users"
  add_foreign_key "matches", "users", column: "target_id"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "teams", "users", column: "creator_id"
end
