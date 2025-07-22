module Api
  module V1
    class ChunkedUploadController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_authentication_user!
      
      # POST /api/v1/chunked_upload/init
      def init
        filename = params[:filename]
        file_size = params[:file_size].to_i
        chunk_size = params[:chunk_size] || 5.megabytes
        
        # Validate file size
        if file_size > 500.megabytes
          render json: { error: 'File size exceeds maximum limit of 500MB' }, status: :bad_request
          return
        end
        
        # Create upload session
        upload_session = ChunkedUpload.create!(
          user: current_authentication_user,
          filename: filename,
          file_size: file_size,
          chunk_size: chunk_size,
          total_chunks: (file_size.to_f / chunk_size).ceil,
          status: 'initialized'
        )
        
        render json: {
          upload_id: upload_session.id,
          chunk_size: chunk_size,
          total_chunks: upload_session.total_chunks
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # POST /api/v1/chunked_upload/chunk
      def upload_chunk
        upload_id = params[:upload_id]
        chunk_number = params[:chunk_number].to_i
        chunk_data = params[:chunk]
        
        upload_session = current_authentication_user.chunked_uploads.find(upload_id)
        
        # Validate chunk number
        if chunk_number < 0 || chunk_number >= upload_session.total_chunks
          render json: { error: 'Invalid chunk number' }, status: :bad_request
          return
        end
        
        # Save chunk to temporary storage
        chunk_path = chunk_file_path(upload_session, chunk_number)
        FileUtils.mkdir_p(File.dirname(chunk_path))
        
        File.open(chunk_path, 'wb') do |file|
          file.write(chunk_data.read)
        end
        
        # Update uploaded chunks
        upload_session.uploaded_chunks ||= []
        upload_session.uploaded_chunks << chunk_number unless upload_session.uploaded_chunks.include?(chunk_number)
        upload_session.status = 'uploading'
        upload_session.save!
        
        # Check if all chunks are uploaded
        if upload_session.uploaded_chunks.size == upload_session.total_chunks
          # Queue job to assemble chunks
          AssembleChunksJob.perform_later(upload_session.id)
        end
        
        render json: {
          chunk_number: chunk_number,
          uploaded_chunks: upload_session.uploaded_chunks.size,
          total_chunks: upload_session.total_chunks,
          progress: (upload_session.uploaded_chunks.size.to_f / upload_session.total_chunks * 100).round(2)
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/chunked_upload/status/:upload_id
      def status
        upload_id = params[:upload_id]
        upload_session = current_authentication_user.chunked_uploads.find(upload_id)
        
        render json: {
          upload_id: upload_session.id,
          status: upload_session.status,
          filename: upload_session.filename,
          uploaded_chunks: upload_session.uploaded_chunks&.size || 0,
          total_chunks: upload_session.total_chunks,
          progress: calculate_progress(upload_session),
          file_id: upload_session.excel_file_id,
          error: upload_session.error_message
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Upload session not found' }, status: :not_found
      end
      
      # DELETE /api/v1/chunked_upload/cancel/:upload_id
      def cancel
        upload_id = params[:upload_id]
        upload_session = current_authentication_user.chunked_uploads.find(upload_id)
        
        # Clean up chunks
        cleanup_chunks(upload_session)
        
        upload_session.update!(status: 'cancelled')
        
        render json: { message: 'Upload cancelled successfully' }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      private
      
      def chunk_file_path(upload_session, chunk_number)
        Rails.root.join('tmp', 'chunks', upload_session.id.to_s, "chunk_#{chunk_number}")
      end
      
      def calculate_progress(upload_session)
        return 100.0 if upload_session.status == 'completed'
        return 0.0 if upload_session.uploaded_chunks.nil?
        
        (upload_session.uploaded_chunks.size.to_f / upload_session.total_chunks * 100).round(2)
      end
      
      def cleanup_chunks(upload_session)
        chunk_dir = Rails.root.join('tmp', 'chunks', upload_session.id.to_s)
        FileUtils.rm_rf(chunk_dir) if Dir.exist?(chunk_dir)
      end
    end
  end
end