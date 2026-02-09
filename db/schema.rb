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

ActiveRecord::Schema[8.1].define(version: 2026_02_10_030002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_claims", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "verification_data"
    t.string "verification_method"
    t.datetime "verified_at"
    t.index ["agent_id"], name: "index_agent_claims_on_agent_id"
    t.index ["user_id"], name: "index_agent_claims_on_user_id"
  end

  create_table "agent_interactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "interaction_type", null: false
    t.text "notes"
    t.string "outcome", null: false
    t.bigint "reporter_agent_id", null: false
    t.decimal "reporter_score_at_time", precision: 5, scale: 2
    t.boolean "success", default: false, null: false
    t.bigint "target_agent_id", null: false
    t.decimal "target_score_at_time", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.index ["interaction_type"], name: "index_agent_interactions_on_interaction_type"
    t.index ["reporter_agent_id", "target_agent_id"], name: "idx_interactions_reporter_target"
    t.index ["reporter_agent_id"], name: "index_agent_interactions_on_reporter_agent_id"
    t.index ["target_agent_id"], name: "index_agent_interactions_on_target_agent_id"
  end

  create_table "agent_scores", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.jsonb "breakdown"
    t.datetime "created_at", null: false
    t.string "decay_rate"
    t.datetime "evaluated_at"
    t.datetime "expires_at"
    t.datetime "last_verified_at"
    t.datetime "next_eval_scheduled_at"
    t.integer "overall_score"
    t.decimal "score_at_eval"
    t.integer "tier"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_agent_scores_on_agent_id"
  end

  create_table "agent_telemetry_stats", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.decimal "avg_duration_ms"
    t.datetime "created_at", null: false
    t.jsonb "error_types"
    t.decimal "p95_duration_ms"
    t.datetime "period_end"
    t.datetime "period_start"
    t.decimal "success_rate"
    t.integer "total_events"
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_agent_telemetry_stats_on_agent_id"
  end

  create_table "agents", force: :cascade do |t|
    t.string "api_endpoint"
    t.string "api_key"
    t.string "builder_name"
    t.string "builder_url"
    t.string "category"
    t.string "changelog_url"
    t.string "claim_status", default: "unclaimed"
    t.datetime "claimed_at"
    t.bigint "claimed_by_user_id"
    t.datetime "created_at", null: false
    t.string "decay_rate", default: "standard"
    t.string "demo_url"
    t.string "description"
    t.string "documentation_url"
    t.boolean "featured", default: false
    t.integer "github_id"
    t.datetime "github_last_updated_at"
    t.string "language"
    t.datetime "last_verified_at"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.datetime "next_eval_scheduled_at"
    t.string "owner"
    t.boolean "published", default: true
    t.string "repo_url"
    t.decimal "score", precision: 5, scale: 2
    t.decimal "score_at_eval", precision: 5, scale: 2
    t.string "slug", null: false
    t.integer "stars"
    t.string "tagline"
    t.decimal "tier0_bus_factor", precision: 5, scale: 2
    t.decimal "tier0_community", precision: 5, scale: 2
    t.decimal "tier0_dependency_risk", precision: 5, scale: 2
    t.decimal "tier0_documentation", precision: 5, scale: 2
    t.decimal "tier0_license", precision: 5, scale: 2
    t.decimal "tier0_maintenance", precision: 5, scale: 2
    t.decimal "tier0_repo_health", precision: 5, scale: 2
    t.decimal "tier1_accuracy", precision: 5, scale: 4
    t.decimal "tier1_completion_rate", precision: 5, scale: 4
    t.decimal "tier1_cost_efficiency", precision: 5, scale: 4
    t.decimal "tier1_safety", precision: 5, scale: 4
    t.decimal "tier1_scope_discipline", precision: 5, scale: 4
    t.datetime "updated_at", null: false
    t.text "use_case"
    t.string "website_url"
    t.index ["category"], name: "index_agents_on_category"
    t.index ["claimed_by_user_id"], name: "index_agents_on_claimed_by_user_id"
    t.index ["featured", "stars"], name: "index_agents_on_featured_and_stars", order: { stars: :desc }
    t.index ["featured"], name: "index_agents_on_featured"
    t.index ["github_id"], name: "index_agents_on_github_id", unique: true
    t.index ["language"], name: "index_agents_on_language"
    t.index ["name"], name: "index_agents_on_name"
    t.index ["published"], name: "index_agents_on_published"
    t.index ["score"], name: "index_agents_on_score"
    t.index ["slug"], name: "index_agents_on_slug", unique: true
    t.index ["stars"], name: "index_agents_on_stars", order: :desc
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "allowed_ips", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name"
    t.string "token"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["last_used_at"], name: "index_api_keys_on_last_used_at"
    t.index ["token"], name: "index_api_keys_on_token"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "certifications", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "reviewed_at"
    t.text "reviewer_notes"
    t.integer "status"
    t.integer "tier"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_certifications_on_agent_id"
  end

  create_table "claim_requests", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "github_verification"
    t.datetime "requested_at"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "verified_at"
    t.index ["agent_id"], name: "index_claim_requests_on_agent_id"
    t.index ["user_id"], name: "index_claim_requests_on_user_id"
  end

  create_table "eval_runs", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.text "agent_output"
    t.datetime "completed_at"
    t.decimal "cost_usd"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.bigint "eval_task_id", null: false
    t.jsonb "metrics"
    t.datetime "started_at"
    t.string "status"
    t.integer "tokens_used"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_eval_runs_on_agent_id"
    t.index ["eval_task_id"], name: "index_eval_runs_on_eval_task_id"
  end

  create_table "eval_tasks", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "difficulty"
    t.jsonb "evaluation_criteria"
    t.jsonb "expected_output"
    t.integer "max_tokens"
    t.string "name"
    t.text "prompt"
    t.integer "timeout_seconds"
    t.datetime "updated_at", null: false
  end

  create_table "evaluations", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "commit_sha"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "notes"
    t.jsonb "raw_data", default: {}
    t.decimal "score", precision: 5, scale: 2
    t.jsonb "scores", default: {}
    t.datetime "started_at"
    t.string "status", default: "pending"
    t.string "tier", null: false
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["agent_id", "tier", "created_at"], name: "index_evaluations_on_agent_id_and_tier_and_created_at"
    t.index ["agent_id"], name: "index_evaluations_on_agent_id"
    t.index ["status"], name: "index_evaluations_on_status"
    t.index ["tier"], name: "index_evaluations_on_tier"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.boolean "comparison_mentions", default: false
    t.datetime "created_at", null: false
    t.boolean "email_enabled", default: true
    t.boolean "new_eval_results", default: true
    t.boolean "score_changes", default: true
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["agent_id"], name: "index_notification_preferences_on_agent_id"
    t.index ["user_id", "agent_id"], name: "index_notification_preferences_on_user_id_and_agent_id", unique: true
    t.index ["user_id"], name: "index_notification_preferences_on_user_id"
  end

  create_table "pending_agents", force: :cascade do |t|
    t.integer "confidence_score"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discovered_at"
    t.string "github_url", null: false
    t.string "language"
    t.string "license"
    t.string "name", null: false
    t.string "owner"
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "stars"
    t.string "status", default: "pending", null: false
    t.jsonb "topics", default: []
    t.datetime "updated_at", null: false
    t.index ["confidence_score"], name: "index_pending_agents_on_confidence_score"
    t.index ["github_url"], name: "index_pending_agents_on_github_url", unique: true
    t.index ["reviewed_by_id"], name: "index_pending_agents_on_reviewed_by_id"
    t.index ["status"], name: "index_pending_agents_on_status"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "safety_scores", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "badge"
    t.jsonb "breakdown"
    t.datetime "created_at", null: false
    t.decimal "overall_score"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_safety_scores_on_agent_id"
  end

  create_table "security_audits", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.date "audit_date"
    t.string "audit_type"
    t.string "auditor"
    t.datetime "created_at", null: false
    t.date "expires_at"
    t.jsonb "findings"
    t.boolean "passed"
    t.string "report_url"
    t.jsonb "severity_summary"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_security_audits_on_agent_id"
  end

  create_table "security_certifications", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "badge_url"
    t.string "certification_type"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "issued_at"
    t.string "issuer"
    t.string "level"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_security_certifications_on_agent_id"
  end

  create_table "security_scans", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "findings"
    t.boolean "passed"
    t.string "scan_type"
    t.datetime "scanned_at"
    t.jsonb "severity_counts"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_security_scans_on_agent_id"
  end

  create_table "telemetry_events", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type"
    t.jsonb "metadata"
    t.jsonb "metrics"
    t.datetime "received_at"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_telemetry_events_on_agent_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "github_uid"
    t.string "github_username"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "role_id"
    t.bigint "user_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.integer "attempt_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "error_message"
    t.string "event_type", null: false
    t.datetime "next_retry_at"
    t.jsonb "payload", default: {}
    t.text "response_body"
    t.integer "response_code"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "webhook_endpoint_id", null: false
    t.index ["next_retry_at"], name: "index_webhook_deliveries_on_next_retry_at"
    t.index ["status"], name: "index_webhook_deliveries_on_status"
    t.index ["webhook_endpoint_id", "created_at"], name: "index_webhook_deliveries_on_webhook_endpoint_id_and_created_at"
    t.index ["webhook_endpoint_id"], name: "index_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "webhook_endpoints", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.boolean "enabled", default: true
    t.string "events", default: [], array: true
    t.integer "failure_count", default: 0
    t.datetime "last_triggered_at"
    t.string "secret"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["agent_id", "enabled"], name: "index_webhook_endpoints_on_agent_id_and_enabled"
    t.index ["agent_id"], name: "index_webhook_endpoints_on_agent_id"
    t.index ["url"], name: "index_webhook_endpoints_on_url"
  end

  add_foreign_key "agent_claims", "agents"
  add_foreign_key "agent_claims", "users"
  add_foreign_key "agent_interactions", "agents", column: "reporter_agent_id"
  add_foreign_key "agent_interactions", "agents", column: "target_agent_id"
  add_foreign_key "agent_scores", "agents"
  add_foreign_key "agent_telemetry_stats", "agents"
  add_foreign_key "agents", "users", column: "claimed_by_user_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "certifications", "agents"
  add_foreign_key "claim_requests", "agents"
  add_foreign_key "claim_requests", "users"
  add_foreign_key "eval_runs", "agents"
  add_foreign_key "eval_runs", "eval_tasks"
  add_foreign_key "evaluations", "agents"
  add_foreign_key "notification_preferences", "agents"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "pending_agents", "users", column: "reviewed_by_id"
  add_foreign_key "safety_scores", "agents"
  add_foreign_key "security_audits", "agents"
  add_foreign_key "security_certifications", "agents"
  add_foreign_key "security_scans", "agents"
  add_foreign_key "telemetry_events", "agents"
  add_foreign_key "webhook_deliveries", "webhook_endpoints"
  add_foreign_key "webhook_endpoints", "agents"
end
