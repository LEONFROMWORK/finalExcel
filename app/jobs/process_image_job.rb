# frozen_string_literal: true

##
# Background job for processing images with the 3-tier system
# Handles expensive image processing operations asynchronously
class ProcessImageJob < ApplicationJob
  queue_as :default
  
  # Retry with exponential backoff for temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Don't retry certain permanent failures
  discard_on ThreeTierImageProcessor::ImageProcessingError do |job, error|
    Rails.logger.error "Discarding ProcessImageJob due to permanent error: #{error.message}"
  end

  ##
  # Process a single image with 3-tier system
  #
  # @param image_url [String] URL of the image to process
  # @param context_tags [Array<String>] Tags for processing context
  # @param callback_class [String] Class name to call after processing
  # @param callback_method [String] Method name to call after processing
  # @param callback_args [Array] Additional arguments for callback
  def perform(image_url, context_tags: [], callback_class: nil, callback_method: nil, callback_args: [])
    Rails.logger.info "🚀 Starting image processing job for: #{image_url}"
    
    processor = ThreeTierImageProcessor.new
    
    # Process the image
    result = processor.process_image_url(image_url, context_tags: context_tags)
    
    # Log results
    if result[:success]
      Rails.logger.info "✅ Image processing completed successfully:"
      Rails.logger.info "   - Tier: #{result[:processing_tier]}"
      Rails.logger.info "   - Content Type: #{result[:extracted_content_type]}"
      Rails.logger.info "   - Content Length: #{result[:extracted_content].length} chars"
      Rails.logger.info "   - Steps: #{result[:processing_steps].join(' → ')}"
    else
      Rails.logger.warn "⚠️  Image processing failed: #{result[:error]}"
    end
    
    # Execute callback if provided
    if callback_class && callback_method
      begin
        callback_class.constantize.send(callback_method, result, *callback_args)
      rescue => e
        Rails.logger.error "Callback execution failed: #{e.message}"
      end
    end
    
    result
    
  rescue => e
    Rails.logger.error "❌ ProcessImageJob failed for #{image_url}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  ##
  # Batch process multiple images
  #
  # @param image_urls [Array<String>] URLs of images to process
  # @param context_tags [Array<String>] Tags for processing context
  # @param batch_callback_class [String] Class to call after batch completion
  # @param batch_callback_method [String] Method to call after batch completion
  def self.process_batch(image_urls, context_tags: [], batch_callback_class: nil, batch_callback_method: nil)
    Rails.logger.info "🔄 Starting batch image processing for #{image_urls.size} images"
    
    results = []
    
    # Process each image
    image_urls.each_with_index do |image_url, index|
      Rails.logger.info "Processing image #{index + 1}/#{image_urls.size}: #{image_url}"
      
      job = ProcessImageJob.perform_now(
        image_url,
        context_tags: context_tags
      )
      
      results << {
        image_url: image_url,
        result: job
      }
      
      # Small delay between images to be respectful
      sleep(0.5) if index < image_urls.size - 1
    end
    
    # Execute batch callback
    if batch_callback_class && batch_callback_method
      begin
        batch_callback_class.constantize.send(batch_callback_method, results)
      rescue => e
        Rails.logger.error "Batch callback execution failed: #{e.message}"
      end
    end
    
    Rails.logger.info "✅ Batch processing completed. Success rate: #{calculate_success_rate(results)}%"
    
    results
  end

  private

  def self.calculate_success_rate(results)
    return 0 if results.empty?
    
    successful = results.count { |r| r[:result][:success] }
    ((successful.to_f / results.size) * 100).round(1)
  end
end