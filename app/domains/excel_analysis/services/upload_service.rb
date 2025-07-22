# frozen_string_literal: true

module ExcelAnalysis
  module Services
    class UploadService < ::Shared::BaseClasses::ApplicationService
      attr_reader :file, :user

      def initialize(file:, user:)
        @file = file
        @user = user
      end

      def call
        validate_file
        return failure(errors, code: :invalid_file) if errors.any?

        excel_file = create_excel_file
        return failure(excel_file.errors.full_messages, code: :creation_failed) unless excel_file.persisted?

        success(excel_file, message: "File uploaded successfully")
      rescue StandardError => e
        Rails.logger.error "Upload failed: #{e.message}"
        failure([ "Upload failed: #{e.message}" ], code: :upload_error)
      end

      private

      def validate_file
        errors << "File is required" unless file.present?
        errors << "File must be less than 50MB" if file && file.size > 50.megabytes

        if file && !valid_format?
          errors << "File must be an Excel file (.xlsx or .xls)"
        end
      end

      def valid_format?
        allowed_formats = %w[
          application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
          application/vnd.ms-excel
        ]
        allowed_formats.include?(file.content_type)
      end

      def create_excel_file
        ExcelFile.create!(
          user: user,
          filename: file.original_filename,
          file: file,
          file_size: file.size,
          status: :pending
        )
      end

      def errors
        @errors ||= []
      end
    end
  end
end
