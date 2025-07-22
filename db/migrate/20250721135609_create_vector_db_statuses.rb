class CreateVectorDbStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :vector_db_statuses do |t|
      t.string :source_type, null: false  # CollectionTask, PipedataImport, etc.
      t.string :source_id, null: false    # Task ID or Import ID
      t.string :status, null: false, default: 'pending'  # pending, processing, completed, failed
      t.integer :progress, default: 0
      t.integer :total_items, default: 0
      t.integer :processed_items, default: 0
      t.integer :failed_items, default: 0
      t.jsonb :error_messages, default: []
      t.jsonb :metadata, default: {}  # 추가 정보 (source_name, task_type, etc.)
      t.datetime :started_at
      t.datetime :completed_at
      t.float :avg_processing_time  # 평균 처리 시간 (ms)
      t.integer :embeddings_created, default: 0  # 생성된 임베딩 수

      t.timestamps
    end

    # 인덱스 추가
    add_index :vector_db_statuses, [ :source_type, :source_id ], unique: true
    add_index :vector_db_statuses, :status
    add_index :vector_db_statuses, :started_at
    add_index :vector_db_statuses, :created_at
  end
end
