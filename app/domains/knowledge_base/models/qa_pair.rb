# frozen_string_literal: true

module KnowledgeBase
  class QaPair < ApplicationRecord
    # Include neighbor for vector similarity search
    has_neighbors :embedding

    # Validations
    validates :question, :answer, presence: true
    validates :quality_score, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    }
    validates :source, inclusion: {
      in: %w[stackoverflow reddit oppadu mrexcel user_generated excel_analysis]
    }

    # Scopes
    scope :approved, -> { where(approved: true) }
    scope :high_quality, -> { where("quality_score >= ?", 0.8) }
    scope :by_source, ->(source) { where(source: source) }
    scope :recent, -> { order(created_at: :desc) }
    scope :popular, -> { order(usage_count: :desc) }

    # Callbacks
    before_validation :set_default_quality_score
    after_create_commit :generate_embedding_async

    # Class methods
    def self.search_similar(query_embedding, limit: 5, threshold: 0.8)
      # Use raw SQL for better performance with pgvector
      sql = <<-SQL
        SELECT qa_pairs.*, 
               (embedding <=> CAST(? AS vector)) AS distance
        FROM qa_pairs
        WHERE approved = true
          AND quality_score >= ?
          AND embedding IS NOT NULL
        ORDER BY embedding <=> CAST(? AS vector)
        LIMIT ?
      SQL
      
      find_by_sql([sql, query_embedding, threshold, query_embedding, limit])
    end

    def self.search_by_text(query)
      where("question ILIKE :query OR answer ILIKE :query", query: "%#{query}%")
        .approved
        .high_quality
    end

    # Instance methods
    def increment_usage!
      increment!(:usage_count)
    end

    def approve!
      update!(approved: true)
    end

    def reject!
      update!(approved: false)
    end

    def source_display
      source.humanize.titleize
    end

    private

    def set_default_quality_score
      self.quality_score ||= 0.5
    end

    def generate_embedding_async
      GenerateEmbeddingJob.perform_later(self.class.name, id)
    end
  end
end
