# frozen_string_literal: true

class CleanupStaleUploadsJob < ApplicationJob
  queue_as :low
  
  def perform
    cleanup_expired_chunked_uploads
    cleanup_orphaned_chunks
    cleanup_old_temp_files
    
    # Schedule next cleanup
    self.class.set(wait: 1.hour).perform_later
  end
  
  private
  
  def cleanup_expired_chunked_uploads
    expired_uploads = ChunkedUpload.where('expires_at < ?', Time.current)
                                   .or(ChunkedUpload.stale)
    
    expired_uploads.find_each do |upload|
      Rails.logger.info "Cleaning up expired chunked upload: #{upload.id}"
      
      # Clean up chunks
      cleanup_chunks(upload)
      
      # Delete record
      upload.destroy
    end
    
    Rails.logger.info "Cleaned up #{expired_uploads.count} expired uploads"
  end
  
  def cleanup_orphaned_chunks
    chunks_dir = Rails.root.join('tmp', 'chunks')
    return unless Dir.exist?(chunks_dir)
    
    # Get all upload IDs that have chunk directories
    chunk_dirs = Dir.entries(chunks_dir).select { |f| f =~ /^\d+$/ }
    
    # Get valid upload IDs
    valid_ids = ChunkedUpload.pluck(:id).map(&:to_s)
    
    # Remove orphaned directories
    orphaned_dirs = chunk_dirs - valid_ids
    
    orphaned_dirs.each do |dir_name|
      dir_path = chunks_dir.join(dir_name)
      FileUtils.rm_rf(dir_path)
      Rails.logger.info "Removed orphaned chunk directory: #{dir_path}"
    end
  end
  
  def cleanup_old_temp_files
    temp_dir = Rails.root.join('tmp', 'uploads')
    return unless Dir.exist?(temp_dir)
    
    # Remove files older than 24 hours
    Dir.glob(temp_dir.join('*')).each do |file|
      next unless File.file?(file)
      
      file_age = Time.current - File.mtime(file)
      
      if file_age > 24.hours
        File.delete(file)
        Rails.logger.info "Removed old temp file: #{file}"
      end
    end
  end
  
  def cleanup_chunks(upload)
    chunk_dir = Rails.root.join('tmp', 'chunks', upload.id.to_s)
    FileUtils.rm_rf(chunk_dir) if Dir.exist?(chunk_dir)
  rescue StandardError => e
    Rails.logger.error "Failed to cleanup chunks for upload #{upload.id}: #{e.message}"
  end
end