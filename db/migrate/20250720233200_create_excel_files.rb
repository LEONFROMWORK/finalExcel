# frozen_string_literal: true

class CreateExcelFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :excel_files do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :file_url
      t.integer :status, default: 0 # 0: pending, 1: processing, 2: completed, 3: failed
      t.integer :file_size
      t.jsonb :metadata, default: {}
      t.jsonb :analysis_result, default: {}
      t.integer :errors_found, default: 0
      t.integer :errors_fixed, default: 0

      t.timestamps
    end

    add_index :excel_files, :status
    add_index :excel_files, :created_at
  end
end
