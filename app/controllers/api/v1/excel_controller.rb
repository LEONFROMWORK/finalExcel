module Api
  module V1
    class ExcelController < Api::V1::ApiController
      def initialize
        super
        @python_client = PythonServiceClient.new
      end

      # POST /api/v1/excel_analysis/files
      def upload
        file = params[:file]

        unless file.present?
          render json: { error: "No file provided" }, status: :bad_request
          return
        end

        # Save file temporarily
        upload_dir = Rails.root.join("tmp", "uploads")
        FileUtils.mkdir_p(upload_dir)

        # Sanitize filename to prevent path traversal
        safe_filename = File.basename(file.original_filename)
        filename = "#{SecureRandom.uuid}_#{safe_filename}"
        filepath = upload_dir.join(filename)

        File.open(filepath, "wb") do |f|
          f.write(file.read)
        end

        # Create Excel file record
        excel_file = current_user.excel_files.create!(
          filename: file.original_filename,
          file_url: "/tmp/uploads/#{filename}",
          file_size: file.size,
          status: "uploaded"
        )

        render json: {
          id: excel_file.id,
          filename: excel_file.filename,
          file_url: excel_file.file_url,
          file_size: excel_file.file_size
        }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/analyze
      def analyze
        file_id = params[:file_id]
        excel_file = current_user.excel_files.find(file_id)

        # Prepare file for Python service
        file_path = Rails.root.join("tmp", "uploads", File.basename(excel_file.file_url))

        # Call Python service for analysis
        begin
          result = @python_client.analyze_excel(file_path, params[:user_query])

          excel_file.update!(
            analysis_result: result,
            status: "analyzed",
            errors_found: result.dig("file_analysis", "summary", "total_errors") || 0
          )

          # Generate embedding for RAG system
          GenerateEmbeddingJob.perform_later("ExcelAnalysis::ExcelFile", excel_file.id)

          render json: result
        rescue StandardError => e
          Rails.logger.error "Excel analysis failed: #{e.message}"
          render json: { error: "Analysis failed" }, status: :internal_server_error
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/modify
      def modify
        file_id = params[:file_id]
        excel_file = current_user.excel_files.find(file_id)

        # Provide absolute URL for Python service
        host = request.protocol + request.host_with_port
        absolute_file_url = host + excel_file.file_url

        # Call Python service for modifications
        begin
          result = @python_client.modify_excel(absolute_file_url, params[:modifications])

          # Save modified file info
          excel_file.update!(
            status: "modified",
            errors_fixed: result["modifications_log"].count { |log| log["status"] == "success" }
          )

          render json: result
        rescue StandardError => e
          Rails.logger.error "Excel modification failed: #{e.message}"
          render json: { error: "Modification failed" }, status: :internal_server_error
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/create-from-template
      def create_from_template
        template_id = params[:template_id]
        customizations = params[:customizations] || {}

        # Call Python service
        begin
          result = @python_client.create_from_template(template_id, customizations)

          # Create Excel file record
          excel_file = current_user.excel_files.create!(
            filename: "template_#{template_id}.xlsx",
            file_url: result["file_url"],
            status: "created",
            metadata: { template_id: template_id }
          )

          render json: {
            file_id: excel_file.id,
            file_url: result["file_url"],
            template_id: template_id
          }
        rescue StandardError => e
          Rails.logger.error "Template creation failed: #{e.message}"
          render json: { error: "Template creation failed" }, status: :internal_server_error
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/create-from-ai
      def create_from_ai
        description = params[:description]
        requirements = params[:requirements] || []

        # Call Python service
        begin
          result = @python_client.create_from_ai(description, requirements)

          # Create Excel file record
          excel_file = current_user.excel_files.create!(
            filename: "ai_generated.xlsx",
            file_url: result["file_url"],
            status: "created",
            metadata: { ai_generated: true, description: description }
          )

          render json: {
            file_id: excel_file.id,
            file_url: result["file_url"],
            structure: result["structure"]
          }
        rescue StandardError => e
          Rails.logger.error "AI generation failed: #{e.message}"
          render json: { error: "AI generation failed" }, status: :internal_server_error
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/uploads/excel/:file_url
      def download
        # Sanitize filename to prevent path traversal
        filename = File.basename(params[:file_url])
        filepath = Rails.root.join("tmp", "uploads", filename)

        # Verify the file path is within allowed directory
        unless filepath.to_s.start_with?(Rails.root.join("tmp", "uploads").to_s) && File.exist?(filepath)
          render json: { error: "File not found" }, status: :not_found
          return
        end

        send_file filepath,
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    disposition: "attachment"
      end

      # GET /api/v1/tmp/uploads/:file_url
      def serve_temp_file
        # Sanitize filename to prevent path traversal
        filename = File.basename(params[:file_url])
        filepath = Rails.root.join("tmp", "uploads", filename)

        # Verify the file path is within allowed directory
        unless filepath.to_s.start_with?(Rails.root.join("tmp", "uploads").to_s) && File.exist?(filepath)
          render json: { error: "File not found" }, status: :not_found
          return
        end

        send_file filepath,
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    disposition: "inline"
      end

      # POST /api/v1/excel_analysis/analyze-vba
      def analyze_vba
        file_id = params[:file_id]
        excel_file = current_user.excel_files.find(file_id)

        # Prepare file for Python service
        file_path = Rails.root.join("tmp", "uploads", File.basename(excel_file.file_url))

        # Call Python service for VBA analysis
        begin
          result = @python_client.analyze_vba(file_path)

          # Update Excel file with VBA analysis result
          excel_file.update!(
            metadata: excel_file.metadata.merge(vba_analysis: result)
          )

          render json: result
        rescue StandardError => e
          Rails.logger.error "VBA analysis failed: #{e.message}"
          render json: { error: "VBA analysis failed" }, status: :internal_server_error
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/analyze-image
      def analyze_image
        image = params[:image]
        analysis_type = params[:analysis_type] || "auto"

        unless image.present?
          render json: { error: "No image provided" }, status: :bad_request
          return
        end

        # Save image temporarily
        upload_dir = Rails.root.join("tmp", "uploads")
        FileUtils.mkdir_p(upload_dir)

        # Sanitize filename to prevent path traversal
        safe_filename = File.basename(image.original_filename)
        filename = "#{SecureRandom.uuid}_#{safe_filename}"
        filepath = upload_dir.join(filename)

        File.open(filepath, "wb") do |f|
          f.write(image.read)
        end

        # Call Python service for image analysis
        begin
          result = @python_client.analyze_image(filepath, analysis_type)
          render json: result
        rescue StandardError => e
          Rails.logger.error "Image analysis failed: #{e.message}"
          render json: { error: "Image analysis failed" }, status: :internal_server_error
        ensure
          # Clean up temporary file
          File.delete(filepath) if File.exist?(filepath)
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/images-to-excel
      def images_to_excel
        images = params[:images] || []
        merge_strategy = params[:merge_strategy] || "separate_sheets"

        if images.empty?
          render json: { error: "No images provided" }, status: :bad_request
          return
        end

        # Save images temporarily
        upload_dir = Rails.root.join("tmp", "uploads")
        FileUtils.mkdir_p(upload_dir)

        image_paths = []
        images.each do |image|
          # Sanitize filename to prevent path traversal
          safe_filename = File.basename(image.original_filename)
          filename = "#{SecureRandom.uuid}_#{safe_filename}"
          filepath = upload_dir.join(filename)

          File.open(filepath, "wb") do |f|
            f.write(image.read)
          end

          image_paths << filepath
        end

        begin
          # Call Python service
          result = @python_client.images_to_excel(image_paths, merge_strategy)

          # Create Excel file record
          excel_file = current_user.excel_files.create!(
            filename: "images_converted.xlsx",
            status: "created",
            metadata: {
              from_images: true,
              image_count: images.length,
              merge_strategy: merge_strategy
            }
          )

          render json: {
            file_id: excel_file.id,
            excel_structure: result["excel_structure"],
            processed_images: result["processed_images"]
          }
        rescue StandardError => e
          Rails.logger.error "Image to Excel conversion failed: #{e.message}"
          render json: { error: "Image to Excel conversion failed" }, status: :internal_server_error
        ensure
          # Clean up temporary files
          image_paths.each do |path|
            File.delete(path) if File.exist?(path)
          end
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/excel_analysis/generate-code
      def generate_code
        user_request = params[:user_request]
        excel_context = params[:excel_context]

        if user_request.blank?
          render json: { error: "User request is required" }, status: :bad_request
          return
        end

        begin
          # Use OpenRouterLLMService to generate code
          llm_service = OpenRouterLLMService.new

          # If we have Excel context, include it
          if excel_context.present? && current_user.excel_files.exists?
            excel_file = current_user.excel_files.last
            result = llm_service.generate_analysis_code(excel_file, user_request)
          else
            # Generate code without specific Excel context
            data_summary = {
              description: "General Excel analysis request",
              user_request: user_request
            }
            messages = [
              {
                role: "system",
                content: "You are a Python data analysis expert. Generate clean, efficient Python code using pandas, numpy, and other data science libraries. Always include error handling and comments."
              },
              {
                role: "user",
                content: "Generate Python code for: #{user_request}"
              }
            ]
            response = llm_service.send(:call_openrouter, messages, { max_tokens: 2048 })
            result = llm_service.send(:extract_code_from_response, response)
          end

          render json: {
            code: result[:code],
            explanation: result[:explanation],
            dependencies: result[:dependencies],
            model_used: result[:model_used]
          }
        rescue StandardError => e
          Rails.logger.error "Code generation failed: #{e.message}"
          render json: { error: "Code generation failed" }, status: :internal_server_error
        end
      end
    end
  end
end
