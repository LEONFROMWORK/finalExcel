class EnablePgvector < ActiveRecord::Migration[8.0]
  def up
    # pgvector extension 활성화
    # Railway에서는 pgvector 템플릿 사용 시 이미 활성화되어 있을 수 있음
    begin
      execute <<-SQL
        CREATE EXTENSION IF NOT EXISTS vector;
      SQL
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn "pgvector extension could not be created: #{e.message}"
      Rails.logger.warn "Falling back to float array columns for embeddings"
    end
  end

  def down
    execute <<-SQL
      DROP EXTENSION IF EXISTS vector CASCADE;
    SQL
  end
end
