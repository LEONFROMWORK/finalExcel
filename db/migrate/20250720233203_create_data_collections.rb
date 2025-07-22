# frozen_string_literal: true

class CreateDataCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :data_collections do |t|
      t.string :source_type, null: false # stackoverflow, reddit, oppadu
      t.string :query, null: false
      t.integer :status, default: 0 # 0: queued, 1: running, 2: completed, 3: failed
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :results_count, default: 0
      t.jsonb :results, default: {}
      t.jsonb :error_details, default: {}
      t.integer :progress, default: 0

      t.timestamps
    end

    add_index :data_collections, :status
    add_index :data_collections, :source_type
    add_index :data_collections, :created_at
  end
end
