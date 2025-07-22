# frozen_string_literal: true

# Image Processing System Initializer
# Configures the 3-tier image processing pipeline

Rails.application.configure do
  # Load image processing configuration
  config.image_processing = config_for(:image_processing)

  # Validate required credentials for image processing
  config.after_initialize do
    begin
      # Check for OpenRouter API key
      openrouter_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.openrouter_api_key
      unless openrouter_key.present?
        Rails.logger.warn "⚠️  OpenRouter API key not found. Tier 3 processing will be disabled."
      end

      # Check for Reddit credentials (optional but recommended for Reddit image processing)
      reddit_creds = Rails.application.credentials.reddit
      unless reddit_creds&.client_id && reddit_creds&.client_secret
        Rails.logger.warn "⚠️  Reddit credentials not found. Reddit image bypass will use basic methods only."
      end

      # Log image processing system status
      config = Rails.application.config.image_processing
      Rails.logger.info "🖼️  3-Tier Image Processing System initialized:"
      Rails.logger.info "   - Tier 1: RTesseract OCR (#{config[:ocr_config][:lang]} language)"
      Rails.logger.info "   - Tier 2: Table detection with OpenCV/MiniMagick"
      Rails.logger.info "   - Tier 3: AI enhancement with #{config[:openrouter_config][:tier2_model]} & #{config[:openrouter_config][:tier3_model]}"
      Rails.logger.info "   - Supported formats: #{config[:supported_formats].join(', ')}"
      Rails.logger.info "   - Max image size: #{config[:max_image_size] / 1024 / 1024}MB"

    rescue => e
      Rails.logger.error "❌ Failed to initialize image processing system: #{e.message}"
    end
  end
end

# Add convenience methods to Rails configuration
module ImageProcessingHelpers
  def self.processor
    @processor ||= ThreeTierImageProcessor.new
  end

  def self.cache
    @cache ||= ImageProcessingCache.new
  end

  def self.reddit_bypasser
    @reddit_bypasser ||= RedditImageBypasser.new({
      client_id: Rails.application.credentials.reddit&.client_id,
      client_secret: Rails.application.credentials.reddit&.client_secret,
      username: "ExcelQACollector"
    })
  end
end

# Make helpers available globally
Rails.application.config.to_prepare do
  Object.const_set("ImageProcessingUtils", ImageProcessingHelpers)
end
