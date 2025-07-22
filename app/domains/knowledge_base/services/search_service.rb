# frozen_string_literal: true

module KnowledgeBase
  module Services
    class SearchService < ::Shared::BaseClasses::ApplicationService
      include ::Shared::Interfaces::Cacheable

      attr_reader :query, :options

      def initialize(query:, options: {})
        @query = query
        @options = default_options.merge(options)
      end

      def call
        return failure([ "Query is required" ], code: :missing_query) if query.blank?

        # Use optimized search service
        search_mode = if options[:use_semantic_search]
                        :semantic
        elsif options[:use_hybrid_search]
                        :hybrid
        else
                        :text
        end

        optimized_search = OptimizedSearchService.new(query, {
          mode: search_mode,
          limit: options[:limit],
          quality_threshold: options[:quality_threshold],
          rerank: options[:rerank] != false
        })

        results = optimized_search.search

        success(format_results(results), message: "Search completed")
      rescue StandardError => e
        Rails.logger.error "Search failed: #{e.message}"
        failure([ "Search failed: #{e.message}" ], code: :search_error)
      end

      def cache_key
        "knowledge_search:#{Digest::MD5.hexdigest(query)}:#{options.hash}"
      end

      def cache_expires_in
        5.minutes
      end

      private

      def default_options
        {
          limit: 10,
          use_semantic_search: true,
          use_hybrid_search: false,
          quality_threshold: 0.7,
          include_metadata: false,
          rerank: true
        }
      end

      def format_results(qa_pairs)
        qa_pairs.map do |qa|
          result = {
            id: qa.id,
            question: qa.question,
            answer: qa.answer,
            quality_score: qa.quality_score,
            source: qa.source_display,
            usage_count: qa.usage_count
          }

          if options[:include_metadata]
            result[:metadata] = qa.metadata
          end

          result
        end
      end
    end
  end
end
