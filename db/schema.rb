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

ActiveRecord::Schema[8.0].define(version: 2025_07_22_100319) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analysis_results", force: :cascade do |t|
    t.bigint "excel_file_id", null: false
    t.string "analysis_type"
    t.string "status", default: "pending"
    t.jsonb "result_data", default: {}
    t.text "summary"
    t.integer "credits_used", default: 0
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_type"], name: "index_analysis_results_on_analysis_type"
    t.index ["excel_file_id"], name: "index_analysis_results_on_excel_file_id"
    t.index ["status"], name: "index_analysis_results_on_status"
  end

  create_table "api_usage_trackers", force: :cascade do |t|
    t.string "service", null: false
    t.string "model", null: false
    t.integer "tokens_used", default: 0
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.string "request_type"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_api_usage_trackers_on_created_at"
    t.index ["model", "created_at"], name: "index_api_usage_trackers_on_model_and_created_at"
    t.index ["model"], name: "index_api_usage_trackers_on_model"
    t.index ["service", "created_at"], name: "index_api_usage_trackers_on_service_and_created_at"
    t.index ["service"], name: "index_api_usage_trackers_on_service"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_session_id", null: false
    t.integer "role", null: false
    t.text "content", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
    t.index ["created_at"], name: "index_chat_messages_on_created_at"
    t.index ["role"], name: "index_chat_messages_on_role"
  end

  create_table "chat_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.integer "status", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_chat_sessions_on_created_at"
    t.index ["status"], name: "index_chat_sessions_on_status"
    t.index ["user_id"], name: "index_chat_sessions_on_user_id"
  end

  create_table "chunked_uploads", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "excel_file_id"
    t.string "filename", null: false
    t.bigint "file_size", null: false
    t.integer "chunk_size", null: false
    t.integer "total_chunks", null: false
    t.text "uploaded_chunks"
    t.string "status", default: "initialized", null: false
    t.text "error_message"
    t.datetime "expires_at", null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["excel_file_id"], name: "index_chunked_uploads_on_excel_file_id"
    t.index ["expires_at"], name: "index_chunked_uploads_on_expires_at"
    t.index ["status"], name: "index_chunked_uploads_on_status"
    t.index ["user_id", "status"], name: "index_chunked_uploads_on_user_id_and_status"
    t.index ["user_id"], name: "index_chunked_uploads_on_user_id"
  end

  create_table "collection_runs", force: :cascade do |t|
    t.bigint "collection_task_id", null: false
    t.integer "status", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "items_collected", default: 0
    t.integer "items_processed", default: 0
    t.integer "duration"
    t.text "error_message"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "result_summary", default: {}
    t.jsonb "error_details", default: {}
    t.index ["collection_task_id", "created_at"], name: "index_collection_runs_on_collection_task_id_and_created_at"
    t.index ["collection_task_id"], name: "index_collection_runs_on_collection_task_id"
    t.index ["status"], name: "index_collection_runs_on_status"
  end

  create_table "collection_tasks", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "task_type", null: false
    t.integer "schedule", null: false
    t.integer "status", default: 0
    t.jsonb "source_config", default: {}
    t.datetime "next_run_at"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "platform"
    t.integer "requested_count"
    t.integer "collected_count"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.bigint "user_id"
    t.index ["created_by_id"], name: "index_collection_tasks_on_created_by_id"
    t.index ["next_run_at"], name: "index_collection_tasks_on_next_run_at"
    t.index ["platform"], name: "index_collection_tasks_on_platform"
    t.index ["schedule"], name: "index_collection_tasks_on_schedule"
    t.index ["status"], name: "index_collection_tasks_on_status"
    t.index ["task_type"], name: "index_collection_tasks_on_task_type"
    t.index ["user_id"], name: "index_collection_tasks_on_user_id"
  end

  create_table "credit_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "transaction_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "balance_after", precision: 10, scale: 2, null: false
    t.decimal "price_paid", precision: 10, scale: 2, default: "0.0"
    t.string "payment_method"
    t.string "payment_transaction_id"
    t.string "status", default: "completed", null: false
    t.datetime "refunded_at"
    t.bigint "related_transaction_id"
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_transaction_id"], name: "index_credit_transactions_on_payment_transaction_id"
    t.index ["related_transaction_id"], name: "index_credit_transactions_on_related_transaction_id"
    t.index ["status"], name: "index_credit_transactions_on_status"
    t.index ["transaction_type"], name: "index_credit_transactions_on_transaction_type"
    t.index ["user_id", "created_at"], name: "index_credit_transactions_on_user_id_and_created_at"
    t.index ["user_id", "transaction_type"], name: "index_credit_transactions_on_user_id_and_transaction_type"
    t.index ["user_id"], name: "index_credit_transactions_on_user_id"
  end

  create_table "data_collections", force: :cascade do |t|
    t.string "source_type", null: false
    t.string "query", null: false
    t.integer "status", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "results_count", default: 0
    t.jsonb "results", default: {}
    t.jsonb "error_details", default: {}
    t.integer "progress", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_data_collections_on_created_at"
    t.index ["source_type"], name: "index_data_collections_on_source_type"
    t.index ["status"], name: "index_data_collections_on_status"
  end

  create_table "error_pattern_usages", force: :cascade do |t|
    t.bigint "error_pattern_id", null: false
    t.bigint "user_id"
    t.jsonb "context", default: {}
    t.integer "feedback"
    t.boolean "resolved"
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["error_pattern_id", "user_id"], name: "index_error_pattern_usages_on_error_pattern_id_and_user_id"
    t.index ["error_pattern_id"], name: "index_error_pattern_usages_on_error_pattern_id"
    t.index ["used_at"], name: "index_error_pattern_usages_on_used_at"
    t.index ["user_id"], name: "index_error_pattern_usages_on_user_id"
  end

  create_table "error_patterns", force: :cascade do |t|
    t.text "question", null: false
    t.text "answer", null: false
    t.string "error_type", limit: 50
    t.string "category", limit: 50
    t.string "domain", limit: 50
    t.float "confidence", default: 0.5
    t.boolean "auto_generated", default: false
    t.boolean "approved", default: false
    t.integer "usage_count", default: 0
    t.float "effectiveness_score"
    t.bigint "created_by_id"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.text "tags", default: [], array: true
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved"], name: "index_error_patterns_on_approved"
    t.index ["approved_by_id"], name: "index_error_patterns_on_approved_by_id"
    t.index ["auto_generated"], name: "index_error_patterns_on_auto_generated"
    t.index ["category"], name: "index_error_patterns_on_category"
    t.index ["created_by_id"], name: "index_error_patterns_on_created_by_id"
    t.index ["domain"], name: "index_error_patterns_on_domain"
    t.index ["effectiveness_score"], name: "index_error_patterns_on_effectiveness_score"
    t.index ["error_type"], name: "index_error_patterns_on_error_type"
    t.index ["metadata"], name: "index_error_patterns_on_metadata", using: :gin
    t.index ["tags"], name: "index_error_patterns_on_tags", using: :gin
    t.index ["usage_count"], name: "index_error_patterns_on_usage_count"
  end

  create_table "excel_files", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "filename", null: false
    t.string "file_url"
    t.integer "status", default: 0
    t.integer "file_size"
    t.jsonb "metadata", default: {}
    t.jsonb "analysis_result", default: {}
    t.integer "errors_found", default: 0
    t.integer "errors_fixed", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_excel_files_on_created_at"
    t.index ["status"], name: "index_excel_files_on_status"
    t.index ["user_id"], name: "index_excel_files_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "type", null: false
    t.string "title", null: false
    t.text "content"
    t.jsonb "data", default: {}
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.string "action_url"
    t.string "action_text"
    t.string "priority", default: "normal"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_notifications_on_expires_at"
    t.index ["priority"], name: "index_notifications_on_priority"
    t.index ["type"], name: "index_notifications_on_type"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pattern_validations", force: :cascade do |t|
    t.bigint "error_pattern_id", null: false
    t.string "validation_type", limit: 50
    t.float "score"
    t.jsonb "issues", default: {}
    t.string "validated_by", limit: 50
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["error_pattern_id", "validation_type"], name: "idx_on_error_pattern_id_validation_type_9fec8a52df"
    t.index ["error_pattern_id"], name: "index_pattern_validations_on_error_pattern_id"
  end

  create_table "qa_pairs", force: :cascade do |t|
    t.text "question", null: false
    t.text "answer", null: false
    t.float "embedding", default: [], array: true
    t.float "quality_score", default: 0.0
    t.string "source"
    t.jsonb "metadata", default: {}
    t.integer "usage_count", default: 0
    t.boolean "approved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved"], name: "index_qa_pairs_on_approved"
    t.index ["quality_score"], name: "index_qa_pairs_on_quality_score"
    t.index ["source"], name: "index_qa_pairs_on_source"
    t.check_constraint "source::text = ANY (ARRAY['stackoverflow'::character varying, 'reddit'::character varying, 'oppadu'::character varying, 'mrexcel'::character varying, 'user_generated'::character varying, 'excel_analysis'::character varying]::text[])", name: "qa_pairs_source_check"
  end

  create_table "referral_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", null: false
    t.integer "usage_count", default: 0
    t.integer "max_uses"
    t.decimal "credits_per_signup", precision: 10, scale: 2, default: "10.0"
    t.decimal "credits_per_purchase", precision: 10, scale: 2, default: "5.0"
    t.datetime "expires_at"
    t.boolean "is_active", default: true
    t.string "referral_type", default: "general"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_referral_codes_on_code", unique: true
    t.index ["expires_at"], name: "index_referral_codes_on_expires_at"
    t.index ["is_active"], name: "index_referral_codes_on_is_active"
    t.index ["user_id", "is_active"], name: "index_referral_codes_on_user_id_and_is_active"
    t.index ["user_id"], name: "index_referral_codes_on_user_id"
  end

  create_table "referral_rewards", force: :cascade do |t|
    t.integer "referrer_id", null: false
    t.integer "referred_id", null: false
    t.bigint "referral_code_id", null: false
    t.string "reward_type", null: false
    t.decimal "credits_amount", precision: 10, scale: 2, default: "0.0"
    t.string "status", default: "pending", null: false
    t.datetime "rewarded_at"
    t.jsonb "metadata", default: {}
    t.string "transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_referral_rewards_on_created_at"
    t.index ["referral_code_id"], name: "index_referral_rewards_on_referral_code_id"
    t.index ["referred_id", "referral_code_id"], name: "index_referral_rewards_on_referred_id_and_referral_code_id", unique: true
    t.index ["referred_id"], name: "index_referral_rewards_on_referred_id"
    t.index ["referrer_id", "status"], name: "index_referral_rewards_on_referrer_id_and_status"
    t.index ["referrer_id"], name: "index_referral_rewards_on_referrer_id"
    t.index ["status"], name: "index_referral_rewards_on_status"
  end

  create_table "user_activities", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.jsonb "details", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.string "session_id"
    t.jsonb "location", default: {}
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.decimal "credits_used", precision: 10, scale: 4, default: "0.0"
    t.boolean "success", default: false
    t.string "referrer"
    t.string "device_type"
    t.float "response_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "success"], name: "index_user_activities_on_action_and_success"
    t.index ["action"], name: "index_user_activities_on_action"
    t.index ["created_at"], name: "index_user_activities_on_created_at"
    t.index ["session_id"], name: "index_user_activities_on_session_id"
    t.index ["started_at"], name: "index_user_activities_on_started_at"
    t.index ["user_id", "started_at"], name: "index_user_activities_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_user_activities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.integer "role", default: 0
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ai_tier", default: "basic"
    t.datetime "tier_upgraded_at"
    t.datetime "tier_expires_at"
    t.jsonb "monthly_usage", default: {}
    t.integer "credits", default: 100, null: false
    t.string "referral_code_used"
    t.integer "referrer_id"
    t.datetime "referred_at"
    t.boolean "marketing_agreed", default: false
    t.string "subscription_plan", default: "free"
    t.string "subscription_status", default: "active"
    t.datetime "next_billing_date"
    t.boolean "notification_email", default: true
    t.boolean "notification_sms", default: false
    t.string "phone"
    t.string "company"
    t.text "bio"
    t.string "language", default: "ko"
    t.string "timezone", default: "Asia/Seoul"
    t.boolean "two_factor_enabled", default: false
    t.string "two_factor_secret"
    t.datetime "deleted_at"
    t.index ["ai_tier"], name: "index_users_on_ai_tier"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["referral_code_used"], name: "index_users_on_referral_code_used"
    t.index ["referrer_id"], name: "index_users_on_referrer_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tier_expires_at"], name: "index_users_on_tier_expires_at"
  end

  create_table "vba_usage_patterns", force: :cascade do |t|
    t.string "error_pattern", null: false
    t.text "solution_used"
    t.boolean "was_helpful", default: false
    t.bigint "user_id"
    t.float "confidence_score", default: 0.0
    t.text "feedback_text"
    t.string "match_type"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_vba_usage_patterns_on_created_at"
    t.index ["error_pattern", "was_helpful"], name: "index_vba_usage_patterns_on_error_pattern_and_was_helpful"
    t.index ["error_pattern"], name: "index_vba_usage_patterns_on_error_pattern"
    t.index ["user_id"], name: "index_vba_usage_patterns_on_user_id"
    t.index ["was_helpful"], name: "index_vba_usage_patterns_on_was_helpful"
  end

  create_table "vector_db_statuses", force: :cascade do |t|
    t.string "source_type", null: false
    t.string "source_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "progress", default: 0
    t.integer "total_items", default: 0
    t.integer "processed_items", default: 0
    t.integer "failed_items", default: 0
    t.jsonb "error_messages", default: []
    t.jsonb "metadata", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.float "avg_processing_time"
    t.integer "embeddings_created", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_vector_db_statuses_on_created_at"
    t.index ["source_type", "source_id"], name: "index_vector_db_statuses_on_source_type_and_source_id", unique: true
    t.index ["started_at"], name: "index_vector_db_statuses_on_started_at"
    t.index ["status"], name: "index_vector_db_statuses_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "analysis_results", "excel_files"
  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "users"
  add_foreign_key "chunked_uploads", "excel_files"
  add_foreign_key "chunked_uploads", "users"
  add_foreign_key "collection_runs", "collection_tasks"
  add_foreign_key "collection_tasks", "users", column: "created_by_id"
  add_foreign_key "credit_transactions", "credit_transactions", column: "related_transaction_id"
  add_foreign_key "credit_transactions", "users"
  add_foreign_key "error_pattern_usages", "error_patterns"
  add_foreign_key "error_pattern_usages", "users"
  add_foreign_key "error_patterns", "users", column: "approved_by_id"
  add_foreign_key "error_patterns", "users", column: "created_by_id"
  add_foreign_key "excel_files", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "pattern_validations", "error_patterns"
  add_foreign_key "referral_codes", "users"
  add_foreign_key "referral_rewards", "referral_codes"
  add_foreign_key "referral_rewards", "users", column: "referred_id"
  add_foreign_key "referral_rewards", "users", column: "referrer_id"
  add_foreign_key "user_activities", "users"
  add_foreign_key "users", "users", column: "referrer_id"
  add_foreign_key "vba_usage_patterns", "users"
end
