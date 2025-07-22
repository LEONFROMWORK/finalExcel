# frozen_string_literal: true

module KnowledgeBase
  module Repositories
    class QaPairRepository < ::Shared::BaseClasses::ApplicationRepository
      def initialize
        super(QaPair)
      end

      def find_approved
        @model_class.approved
      end

      def find_pending_approval
        @model_class.where(approved: false)
      end

      def find_high_quality(threshold: 0.8)
        @model_class.where("quality_score >= ?", threshold)
      end

      def find_by_source(source)
        @model_class.by_source(source)
      end

      def find_popular(limit: 10)
        @model_class.popular.limit(limit)
      end

      def find_recent(limit: 10)
        @model_class.recent.limit(limit)
      end

      def statistics
        {
          total: count,
          approved: find_approved.count,
          pending: find_pending_approval.count,
          by_source: count_by_source,
          average_quality: average_quality_score,
          total_usage: total_usage_count
        }
      end

      def count_by_source
        @model_class.group(:source).count
      end

      def average_quality_score
        @model_class.average(:quality_score)&.round(2) || 0.0
      end

      def total_usage_count
        @model_class.sum(:usage_count)
      end

      def bulk_approve(ids)
        @model_class.where(id: ids).update_all(approved: true)
      end

      def bulk_reject(ids)
        @model_class.where(id: ids).update_all(approved: false)
      end

      def cleanup_low_quality(threshold: 0.3, max_age_days: 90)
        @model_class
          .where("quality_score < ?", threshold)
          .where("created_at < ?", max_age_days.days.ago)
          .where(usage_count: 0)
          .destroy_all
      end
    end
  end
end
