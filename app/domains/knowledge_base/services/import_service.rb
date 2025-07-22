# frozen_string_literal: true

module KnowledgeBase
  module Services
    class ImportService < ::Shared::BaseClasses::ApplicationService
      attr_reader :data, :source, :options

      def initialize(data:, source:, options: {})
        @data = data
        @source = source
        @options = options
      end

      def call
        validate_data
        return failure(validation_errors, code: :invalid_data) if validation_errors.any?

        imported_count = 0
        failed_items = []

        data.each_with_index do |item, index|
          result = import_single_item(item, index)
          if result[:success]
            imported_count += 1
          else
            failed_items << result
          end
        end

        if failed_items.empty?
          success(
            { imported: imported_count, failed: 0 },
            message: "Successfully imported #{imported_count} Q&A pairs"
          )
        else
          failure(
            failed_items.map { |f| f[:error] },
            code: :partial_failure,
            message: "Imported #{imported_count} items, #{failed_items.size} failed"
          )
        end
      rescue StandardError => e
        Rails.logger.error "Import failed: #{e.message}"
        failure([ "Import failed: #{e.message}" ], code: :import_error)
      end

      private

      def validate_data
        validation_errors << "Data must be an array" unless data.is_a?(Array)
        validation_errors << "Data cannot be empty" if data.empty?
        validation_errors << "Invalid source" unless valid_source?
      end

      def validation_errors
        @validation_errors ||= []
      end

      def valid_source?
        %w[stackoverflow reddit oppadu api].include?(source)
      end

      def import_single_item(item, index)
        qa_pair = build_qa_pair(item)

        if qa_pair.save
          { success: true, index: index }
        else
          {
            success: false,
            index: index,
            error: "Item #{index + 1}: #{qa_pair.errors.full_messages.join(', ')}"
          }
        end
      rescue StandardError => e
        {
          success: false,
          index: index,
          error: "Item #{index + 1}: #{e.message}"
        }
      end

      def build_qa_pair(item)
        QaPair.new(
          question: item["question"] || item[:question],
          answer: item["answer"] || item[:answer],
          quality_score: calculate_quality_score(item),
          source: source,
          metadata: extract_metadata(item),
          approved: options[:auto_approve] || false
        )
      end

      def calculate_quality_score(item)
        score = item["quality_score"] || item[:quality_score] || 0.5
        score.to_f.clamp(0.0, 1.0)
      end

      def extract_metadata(item)
        {
          original_id: item["id"] || item[:id],
          tags: item["tags"] || item[:tags] || [],
          created_at: item["created_at"] || item[:created_at],
          url: item["url"] || item[:url],
          author: item["author"] || item[:author]
        }.compact
      end
    end
  end
end
