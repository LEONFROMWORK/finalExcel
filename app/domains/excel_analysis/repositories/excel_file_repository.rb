# frozen_string_literal: true

module ExcelAnalysis
  module Repositories
    class ExcelFileRepository < ::Shared::BaseClasses::ApplicationRepository
      def initialize
        super(ExcelFile)
      end

      def find_by_user(user_id)
        @model_class.where(user_id: user_id)
      end

      def find_recent(limit: 10)
        @model_class.recent.limit(limit)
      end

      def find_by_status(status)
        @model_class.by_status(status)
      end

      def find_completed_for_user(user_id, limit: nil)
        query = find_by_user(user_id).completed.recent
        query = query.limit(limit) if limit
        query
      end

      def count_by_status(user_id: nil)
        query = user_id ? find_by_user(user_id) : @model_class
        query.group(:status).count
      end

      def total_errors_fixed(user_id: nil)
        query = user_id ? find_by_user(user_id) : @model_class
        query.sum(:errors_fixed)
      end

      def search(query, user_id: nil)
        scope = user_id ? find_by_user(user_id) : @model_class
        scope.where("filename ILIKE ?", "%#{query}%")
      end
    end
  end
end
