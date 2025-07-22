class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    # Foreign key indexes
    add_index :chat_messages, :chat_session_id unless index_exists?(:chat_messages, :chat_session_id)
    add_index :analysis_results, :excel_file_id unless index_exists?(:analysis_results, :excel_file_id)
    add_index :vba_usage_patterns, :user_id unless index_exists?(:vba_usage_patterns, :user_id)
    add_index :excel_files, :user_id unless index_exists?(:excel_files, :user_id)
    # chat_sessions already has user_id index in schema
    # add_index :chat_sessions, :user_id unless index_exists?(:chat_sessions, :user_id)
    # excel_file_id column doesn't exist in chat_sessions

    # Single column indexes for foreign keys that only have composite indexes
    add_index :error_pattern_usages, :error_pattern_id unless index_exists?(:error_pattern_usages, :error_pattern_id)
    add_index :user_activities, :user_id unless index_exists?(:user_activities, :user_id)
    add_index :notifications, :user_id unless index_exists?(:notifications, :user_id)

    # Frequently queried columns
    add_index :referral_rewards, :created_at unless index_exists?(:referral_rewards, :created_at)
    add_index :chat_messages, :role unless index_exists?(:chat_messages, :role)
    add_index :collection_tasks, :created_by_id unless index_exists?(:collection_tasks, :created_by_id)

    # Performance indexes for common queries
    add_index :collection_runs, :collection_task_id unless index_exists?(:collection_runs, :collection_task_id)
  end
end
