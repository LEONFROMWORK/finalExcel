module ExcelAnalysis
  class UpdateService < ApplicationService
    def initialize(file:, modifications:, user:)
      @file = file
      @modifications = modifications
      @user = user
    end

    def call
      return error("File not found") unless @file
      return error("No modifications provided") if @modifications.blank?

      begin
        # Update file status
        @file.update!(status: "processing")

        # Send to Python service for processing
        response = python_client.post(
          "/api/v1/excel/modify",
          {
            file_id: @file.id,
            file_url: rails_blob_url(@file.original_file),
            modifications: @modifications
          }
        )

        if response.success?
          # Save the modified file
          modified_file = download_file(response.body["file_url"])
          @file.processed_file.attach(
            io: modified_file,
            filename: "modified_#{@file.name}",
            content_type: @file.content_type
          )

          # Update metadata
          @file.update!(
            status: "completed",
            metadata: @file.metadata.merge(
              last_modified_at: Time.current,
              modifications_applied: @modifications
            )
          )

          # Deduct credits
          deduct_credits(@user, calculate_modification_cost(@modifications))

          success(
            file: @file,
            download_url: rails_blob_url(@file.processed_file, disposition: "attachment")
          )
        else
          @file.update!(status: "failed")
          error(response.body["error"] || "Modification failed")
        end
      rescue StandardError => e
        @file.update!(status: "failed")
        error("Processing error: #{e.message}")
      end
    end

    private

    def python_client
      @python_client ||= PythonServiceClient.new
    end

    def download_file(url)
      URI.open(url)
    end

    def calculate_modification_cost(modifications)
      base_cost = 20

      # Add costs based on modification types
      modifications.each do |mod|
        case mod["type"]
        when "formula_fix"
          base_cost += 5
        when "vba_modification"
          base_cost += 10
        when "data_cleanup"
          base_cost += 8
        when "add_feature"
          base_cost += 15
        end
      end

      base_cost
    end

    def deduct_credits(user, amount)
      # This will be implemented when credit system is ready
      Rails.logger.info "Deducting #{amount} credits from user #{user.id}"
    end

    def rails_blob_url(attachment, options = {})
      Rails.application.routes.url_helpers.rails_blob_url(attachment, options)
    end
  end
end
