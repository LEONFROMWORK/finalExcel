# frozen_string_literal: true

# Start cleanup job for stale uploads
if Rails.env.production? || Rails.env.development?
  Rails.application.config.after_initialize do
    # Start cleanup job after a delay
    CleanupStaleUploadsJob.set(wait: 5.minutes).perform_later
    
    Rails.logger.info "Chunked upload cleanup job scheduled"
  end
end

# Configure chunked upload settings
Rails.application.config.chunked_upload = {
  max_file_size: 500.megabytes,
  default_chunk_size: 5.megabytes,
  upload_expiration: 24.hours,
  max_concurrent_chunks: 3,
  cleanup_interval: 1.hour
}