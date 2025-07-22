module Api
  module V1
    class StreamingDownloadController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_authentication_user!
      
      include ActionController::Live
      
      # GET /api/v1/streaming_download/:file_id
      def download
        excel_file = current_authentication_user.excel_files.find(params[:file_id])
        
        # Get file path
        file_path = get_file_path(excel_file)
        
        unless File.exist?(file_path)
          render json: { error: 'File not found' }, status: :not_found
          return
        end
        
        # Set headers for streaming
        response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        response.headers['Content-Disposition'] = "attachment; filename=\"#{excel_file.filename}\""
        response.headers['Content-Length'] = excel_file.file_size.to_s
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no' # Disable Nginx buffering
        
        # Stream file in chunks
        stream_file(file_path)
      rescue StandardError => e
        Rails.logger.error "Streaming download failed: #{e.message}"
        response.stream.close rescue nil
      end
      
      # GET /api/v1/streaming_download/:file_id/partial
      def partial_download
        excel_file = current_authentication_user.excel_files.find(params[:file_id])
        file_path = get_file_path(excel_file)
        
        unless File.exist?(file_path)
          render json: { error: 'File not found' }, status: :not_found
          return
        end
        
        # Handle range requests
        if request.headers['Range']
          handle_range_request(excel_file, file_path)
        else
          # Regular download
          download
        end
      rescue StandardError => e
        Rails.logger.error "Partial download failed: #{e.message}"
        render json: { error: 'Download failed' }, status: :internal_server_error
      end
      
      private
      
      def get_file_path(excel_file)
        if excel_file.file_url.start_with?('/')
          Rails.root.join('tmp', 'uploads', File.basename(excel_file.file_url))
        else
          ActiveStorage::Blob.service.path_for(excel_file.file_url)
        end
      end
      
      def stream_file(file_path)
        File.open(file_path, 'rb') do |file|
          while chunk = file.read(1.megabyte)
            response.stream.write(chunk)
            sleep 0.01 # Small delay to prevent overwhelming the client
          end
        end
      ensure
        response.stream.close
      end
      
      def handle_range_request(excel_file, file_path)
        file_size = excel_file.file_size
        range_header = request.headers['Range']
        
        # Parse range header
        if range_header =~ /bytes=(\d+)-(\d*)/
          start_byte = $1.to_i
          end_byte = $2.empty? ? file_size - 1 : $2.to_i
          
          # Validate range
          if start_byte >= file_size || end_byte >= file_size || start_byte > end_byte
            head :requested_range_not_satisfiable
            return
          end
          
          # Set partial content headers
          response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          response.headers['Content-Length'] = (end_byte - start_byte + 1).to_s
          response.headers['Content-Range'] = "bytes #{start_byte}-#{end_byte}/#{file_size}"
          response.headers['Accept-Ranges'] = 'bytes'
          response.headers['Cache-Control'] = 'no-cache'
          
          # Send partial content status
          response.status = 206
          
          # Stream requested range
          File.open(file_path, 'rb') do |file|
            file.seek(start_byte)
            remaining = end_byte - start_byte + 1
            
            while remaining > 0 && !file.eof?
              chunk_size = [1.megabyte, remaining].min
              chunk = file.read(chunk_size)
              break unless chunk
              
              response.stream.write(chunk)
              remaining -= chunk.bytesize
            end
          end
        else
          head :bad_request
        end
      ensure
        response.stream.close rescue nil
      end
    end
  end
end