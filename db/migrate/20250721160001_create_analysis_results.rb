class CreateAnalysisResults < ActiveRecord::Migration[8.0]
  def change
    create_table :analysis_results do |t|
      t.references :excel_file, null: false, foreign_key: true
      t.string :analysis_type
      t.string :status, default: 'pending'
      t.jsonb :result_data, default: {}
      t.text :summary
      t.integer :credits_used, default: 0
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :analysis_results, :status
    add_index :analysis_results, :analysis_type
  end
end