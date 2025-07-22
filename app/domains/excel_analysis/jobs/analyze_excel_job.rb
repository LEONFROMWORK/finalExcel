# frozen_string_literal: true

module ExcelAnalysis
  module Jobs
    class AnalyzeExcelJob < ApplicationJob
      queue_as :default

      retry_on StandardError, wait: 5.seconds, attempts: 3

      def perform(excel_file_id)
        excel_file = ExcelFile.find(excel_file_id)
        return if excel_file.completed? || excel_file.failed?

        result = Services::AnalysisService.call(excel_file: excel_file)

        if result.failure?
          Rails.logger.error "Excel analysis failed: #{result.errors.join(', ')}"
          excel_file.failed!
        end
      end
    end
  end
end
