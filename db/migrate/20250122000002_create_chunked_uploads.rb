class CreateChunkedUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :chunked_uploads do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :excel_file, foreign_key: { to_table: :excel_files }
      
      t.string :filename, null: false
      t.bigint :file_size, null: false
      t.integer :chunk_size, null: false
      t.integer :total_chunks, null: false
      t.text :uploaded_chunks
      
      t.string :status, null: false, default: 'initialized'
      t.text :error_message
      
      t.datetime :expires_at, null: false
      t.datetime :completed_at
      t.datetime :failed_at
      
      t.timestamps
    end
    
    add_index :chunked_uploads, :status
    add_index :chunked_uploads, :expires_at
    add_index :chunked_uploads, [:user_id, :status]
  end
end