# frozen_string_literal: true

module KnowledgeBase
  class QaPairsController < Api::V1::ApiController
    def index
      qa_pairs = repository.find_approved
                          .page(params[:page])
                          .per(params[:per_page] || 20)

      render json: {
        qa_pairs: serialize_qa_pairs(qa_pairs),
        meta: pagination_meta(qa_pairs)
      }
    end

    def show
      qa_pair = repository.find(params[:id])

      if qa_pair && qa_pair.approved?
        qa_pair.increment_usage!
        render json: serialize_qa_pair(qa_pair)
      else
        render json: { error: "Q&A pair not found" }, status: :not_found
      end
    end

    def search
      result = Services::SearchService.call(
        query: params[:query],
        options: search_options
      )

      result.on_success do |results|
        render json: {
          query: params[:query],
          results: results,
          total: results.size
        }
      end.on_failure do |errors, code|
        render json: {
          errors: errors,
          code: code
        }, status: :bad_request
      end
    end

    private

    def repository
      @repository ||= Repositories::QaPairRepository.new
    end

    def search_options
      {
        limit: params[:limit]&.to_i || 10,
        use_semantic_search: params[:semantic] != "false",
        quality_threshold: params[:threshold]&.to_f || 0.7,
        include_metadata: params[:include_metadata] == "true"
      }
    end

    def serialize_qa_pair(qa_pair)
      {
        id: qa_pair.id,
        question: qa_pair.question,
        answer: qa_pair.answer,
        quality_score: qa_pair.quality_score,
        source: qa_pair.source_display,
        usage_count: qa_pair.usage_count,
        created_at: qa_pair.created_at
      }
    end

    def serialize_qa_pairs(qa_pairs)
      qa_pairs.map { |qa| serialize_qa_pair(qa) }
    end

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.current_per_page
      }
    end
  end
end
