class CreateCollectionTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_tasks do |t|
      t.string :name, null: false
      t.text :description
      t.integer :task_type, null: false
      t.integer :schedule, null: false
      t.integer :status, default: 0
      t.jsonb :source_config, default: {}
      t.datetime :next_run_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      
      t.timestamps
    end
    
    add_index :collection_tasks, :status
    add_index :collection_tasks, :task_type
    add_index :collection_tasks, :schedule
    add_index :collection_tasks, :next_run_at
  end
end