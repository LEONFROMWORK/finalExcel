class CreateVbaUsagePatterns < ActiveRecord::Migration[8.0]
  def change
    create_table :vba_usage_patterns do |t|
      t.string :error_pattern, null: false
      t.text :solution_used
      t.boolean :was_helpful, default: false
      t.references :user, null: true, foreign_key: true  # null 허용 (익명 사용자)
      t.float :confidence_score, default: 0.0
      t.text :feedback_text
      t.string :match_type  # exact_match, keyword_match, generic, performance
      t.jsonb :metadata, default: {}  # 추가 정보 저장용

      t.timestamps
    end
    
    # 인덱스 추가
    add_index :vba_usage_patterns, :error_pattern
    add_index :vba_usage_patterns, :was_helpful
    add_index :vba_usage_patterns, [:error_pattern, :was_helpful]
    add_index :vba_usage_patterns, :created_at
  end
end
