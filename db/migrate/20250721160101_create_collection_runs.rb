class CreateCollectionRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_runs do |t|
      t.references :collection_task, null: false, foreign_key: true
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :items_collected, default: 0
      t.integer :items_processed, default: 0
      t.integer :duration
      t.text :error_message
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :collection_runs, :status
    add_index :collection_runs, [ :collection_task_id, :created_at ]
  end
end
