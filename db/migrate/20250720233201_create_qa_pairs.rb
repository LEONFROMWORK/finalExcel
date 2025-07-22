# frozen_string_literal: true

class CreateQaPairs < ActiveRecord::Migration[8.0]
  def change
    create_table :qa_pairs do |t|
      t.text :question, null: false
      t.text :answer, null: false
      # Use float array instead of vector for local testing without pgvector
      if extension_enabled?('vector')
        t.vector :embedding, limit: 1536
      else
        t.float :embedding, array: true, default: []
      end
      t.float :quality_score, default: 0.0
      t.string :source # stackoverflow, reddit, oppadu, user_generated
      t.jsonb :metadata, default: {}
      t.integer :usage_count, default: 0
      t.boolean :approved, default: false

      t.timestamps
    end

    add_index :qa_pairs, :quality_score
    add_index :qa_pairs, :source
    add_index :qa_pairs, :approved
    # Only add vector index if pgvector is available
    if extension_enabled?('vector')
      add_index :qa_pairs, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    end
  end
end
