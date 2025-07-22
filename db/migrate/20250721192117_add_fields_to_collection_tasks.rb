class AddFieldsToCollectionTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_tasks, :platform, :string
    add_column :collection_tasks, :requested_count, :integer
    add_column :collection_tasks, :collected_count, :integer
    add_column :collection_tasks, :error_message, :text
    add_column :collection_tasks, :started_at, :datetime
    add_column :collection_tasks, :completed_at, :datetime
    add_column :collection_tasks, :user_id, :bigint
    
    # Add indexes
    add_index :collection_tasks, :platform
    add_index :collection_tasks, :user_id
  end
end
