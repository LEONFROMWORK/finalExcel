# frozen_string_literal: true

class CreateApiUsageTrackers < ActiveRecord::Migration[8.0]
  def change
    create_table :api_usage_trackers do |t|
      t.string :service, null: false
      t.string :model, null: false
      t.integer :tokens_used, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0.0
      t.string :request_type
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :api_usage_trackers, :service
    add_index :api_usage_trackers, :model
    add_index :api_usage_trackers, :created_at
    add_index :api_usage_trackers, [:service, :created_at]
    add_index :api_usage_trackers, [:model, :created_at]
  end
end