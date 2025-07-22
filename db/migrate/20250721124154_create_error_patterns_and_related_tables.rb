class CreateErrorPatternsAndRelatedTables < ActiveRecord::Migration[8.0]
  def change
    # 오류 패턴 테이블
    create_table :error_patterns do |t|
      t.text :question, null: false
      t.text :answer, null: false
      t.string :error_type, limit: 50
      t.string :category, limit: 50
      t.string :domain, limit: 50
      t.float :confidence, default: 0.5
      t.boolean :auto_generated, default: false
      t.boolean :approved, default: false
      t.integer :usage_count, default: 0
      t.float :effectiveness_score
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text :tags, array: true, default: []
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # 사용 추적 테이블
    create_table :error_pattern_usages do |t|
      t.references :error_pattern, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.jsonb :context, default: {}
      t.integer :feedback # 1-5 rating
      t.boolean :resolved
      t.datetime :used_at

      t.timestamps
    end

    # 검증 결과 테이블
    create_table :pattern_validations do |t|
      t.references :error_pattern, null: false, foreign_key: true
      t.string :validation_type, limit: 50
      t.float :score
      t.jsonb :issues, default: {}
      t.string :validated_by, limit: 50 # 'system' or user_id

      t.timestamps
    end

    # 인덱스 추가
    add_index :error_patterns, :error_type
    add_index :error_patterns, :category
    add_index :error_patterns, :domain
    add_index :error_patterns, :auto_generated
    add_index :error_patterns, :approved
    add_index :error_patterns, :usage_count
    add_index :error_patterns, :effectiveness_score
    add_index :error_patterns, :tags, using: :gin
    add_index :error_patterns, :metadata, using: :gin

    add_index :error_pattern_usages, [ :error_pattern_id, :user_id ]
    add_index :error_pattern_usages, :used_at

    add_index :pattern_validations, [ :error_pattern_id, :validation_type ]
  end
end
