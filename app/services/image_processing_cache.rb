# frozen_string_literal: true

require 'digest'

##
# Local cache service for image processing results
# Mimics the Python LocalCache and APICache functionality
#
# Usage:
#   cache = ImageProcessingCache.new
#   cache.get_image_processing_result(url, type)
#   cache.cache_image_processing_result(url, type, result)
class ImageProcessingCache
  # Default TTL values matching Python implementation
  DEFAULT_TTL = 24.hours.to_i          # 24h for general cache
  IMAGE_PROCESSING_TTL = 7.days.to_i   # 7 days for expensive image processing
  OPENROUTER_TTL = 7.days.to_i         # 7 days for AI responses

  def initialize
    @cache_store = Rails.cache
  end

  # Generate cache key from data
  def generate_key(prefix, data)
    sorted_data = data.sort.to_h.to_json
    hash = Digest::MD5.hexdigest(sorted_data)
    "#{prefix}:#{hash}"
  end

  # Get cached image processing result
  def get_image_processing_result(image_url, processing_type)
    key = generate_key('img_proc', {
      url: image_url,
      type: processing_type
    })
    @cache_store.read(key)
  end

  # Cache image processing result
  def cache_image_processing_result(image_url, processing_type, result)
    key = generate_key('img_proc', {
      url: image_url,
      type: processing_type
    })
    @cache_store.write(key, result, expires_in: IMAGE_PROCESSING_TTL)
  end

  # Get cached OpenRouter API response
  def get_openrouter_response(model, messages, image_url)
    key = generate_key('openrouter', {
      model: model,
      messages: messages,
      image_url: image_url
    })
    @cache_store.read(key)
  end

  # Cache OpenRouter API response
  def cache_openrouter_response(model, messages, image_url, response)
    key = generate_key('openrouter', {
      model: model,
      messages: messages,
      image_url: image_url
    })
    @cache_store.write(key, response, expires_in: OPENROUTER_TTL)
  end

  # Get cached Stack Overflow API response
  def get_stackoverflow_response(endpoint, params)
    key = generate_key('so_api', {
      endpoint: endpoint,
      params: params
    })
    @cache_store.read(key)
  end

  # Cache Stack Overflow API response
  def cache_stackoverflow_response(endpoint, params, response)
    key = generate_key('so_api', {
      endpoint: endpoint,
      params: params
    })
    @cache_store.write(key, response, expires_in: DEFAULT_TTL)
  end

  # Clear expired entries (Rails cache handles this automatically)
  def cleanup_expired
    # Rails.cache handles TTL automatically, but we can force cleanup if needed
    Rails.logger.info "Cache cleanup requested - Rails handles TTL automatically"
  end

  # Get cache statistics (approximation since Rails.cache doesn't expose all stats)
  def get_stats
    {
      cache_store: @cache_store.class.name,
      estimated_size: "N/A (managed by Rails cache)",
      cleanup_strategy: "Automatic TTL-based"
    }
  end
end