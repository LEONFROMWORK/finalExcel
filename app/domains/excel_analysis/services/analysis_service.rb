# frozen_string_literal: true

module ExcelAnalysis
  module Services
    class AnalysisService < ::Shared::BaseClasses::ApplicationService
      include ::Shared::Interfaces::Cacheable

      attr_reader :excel_file

      def initialize(excel_file:)
        @excel_file = excel_file
      end

      def call
        return failure([ "File not found" ], code: :not_found) unless excel_file
        return failure([ "File already analyzed" ], code: :already_analyzed) if excel_file.completed?

        excel_file.processing!

        analysis_result = perform_analysis
        update_excel_file(analysis_result)

        success(excel_file, message: "Analysis completed successfully")
      rescue StandardError => e
        excel_file.failed!
        Rails.logger.error "Analysis failed: #{e.message}"
        failure([ "Analysis failed: #{e.message}" ], code: :analysis_error)
      end

      def cache_key
        "excel_analysis:#{excel_file.id}"
      end

      private

      def perform_analysis
        # Call Python service for analysis
        python_result = call_python_service

        # Process the result
        {
          summary: extract_summary(python_result),
          errors: extract_errors(python_result),
          formulas: extract_formulas(python_result),
          statistics: extract_statistics(python_result),
          recommendations: generate_recommendations(python_result)
        }
      end

      def call_python_service
        # Get the file path
        file_path = if excel_file.file_url.start_with?('/')
                      Rails.root.join('tmp', 'uploads', File.basename(excel_file.file_url))
                    else
                      ActiveStorage::Blob.service.path_for(excel_file.file_url)
                    end
        
        # Call Python service
        python_client = PythonServiceClient.new
        result = python_client.analyze_excel(file_path)
        
        # Transform Python service response to expected format
        {
          rows: result.dig('file_analysis', 'summary', 'total_rows') || 0,
          columns: result.dig('file_analysis', 'summary', 'total_columns') || 0,
          sheets: result.dig('file_analysis', 'summary', 'total_sheets') || 0,
          formulas_count: result.dig('file_analysis', 'summary', 'total_formulas') || 0,
          errors: transform_errors(result.dig('file_analysis', 'errors') || []),
          data_types: result.dig('file_analysis', 'data_types') || {},
          complex_formulas: result.dig('file_analysis', 'formulas', 'complex') || 0,
          simple_formulas: result.dig('file_analysis', 'formulas', 'simple') || 0,
          empty_cells: result.dig('file_analysis', 'summary', 'empty_cells') || 0,
          unique_values: result.dig('file_analysis', 'summary', 'unique_values') || 0
        }
      end
      
      def transform_errors(errors)
        errors.map do |error|
          {
            type: error['error_type'],
            count: error['count'] || 1,
            cells: error['locations'] || []
          }
        end
      end

      def extract_summary(result)
        {
          total_rows: result[:rows],
          total_columns: result[:columns],
          sheets_count: result[:sheets],
          formulas_count: result[:formulas_count]
        }
      end

      def extract_errors(result)
        result[:errors] || []
      end

      def extract_formulas(result)
        {
          total: result[:formulas_count],
          complex: result[:complex_formulas] || 0,
          simple: result[:simple_formulas] || 0
        }
      end

      def extract_statistics(result)
        {
          data_types: result[:data_types],
          empty_cells: result[:empty_cells] || 0,
          unique_values: result[:unique_values] || 0
        }
      end

      def generate_recommendations(result)
        recommendations = []

        if result[:errors].any?
          recommendations << {
            type: "error_fix",
            priority: "high",
            message: "Found #{result[:errors].sum { |e| e[:count] }} errors that need attention"
          }
        end

        recommendations
      end

      def update_excel_file(analysis_result)
        excel_file.update!(
          status: :completed,
          analysis_result: analysis_result,
          errors_found: analysis_result[:errors].sum { |e| e[:count] },
          errors_fixed: 0
        )
      end
    end
  end
end
