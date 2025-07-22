# frozen_string_literal: true

require 'net/http'
require 'json'

# Embedding service using OpenRouter instead of OpenAI directly
class OpenrouterEmbeddingService
  OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/embeddings'
  MODEL = 'openai/text-embedding-3-small' # OpenRouter model name format
  DIMENSIONS = 1536

  def initialize(api_key = ENV['OPENROUTER_API_KEY'])
    @api_key = api_key
  end

  def generate_embedding(text)
    return nil if text.blank?
    
    # Clean and truncate text
    cleaned_text = text.strip.gsub(/\s+/, ' ').truncate(8000)
    
    begin
      response = make_api_request(cleaned_text)
      
      if response['data'] && response['data'][0] && response['data'][0]['embedding']
        embedding = response['data'][0]['embedding']
        
        # Ensure correct dimensions
        if embedding.size != DIMENSIONS
          Rails.logger.warn "Embedding dimension mismatch: expected #{DIMENSIONS}, got #{embedding.size}"
        end
        
        embedding
      else
        Rails.logger.error "Invalid OpenRouter response: #{response.inspect}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Embedding generation failed: #{e.message}"
      nil
    end
  end

  def generate_embeddings_batch(texts)
    texts.map { |text| generate_embedding(text) }
  end

  private

  def make_api_request(text)
    uri = URI(OPENROUTER_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['HTTP-Referer'] = ENV['APP_URL'] || 'http://localhost:3000'
    request['X-Title'] = 'Excel Unified - Embeddings'
    
    request.body = {
      input: text,
      model: MODEL,
      dimensions: DIMENSIONS
    }.to_json

    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      error_body = JSON.parse(response.body) rescue response.body
      raise "OpenRouter API error: #{response.code} - #{error_body}"
    end
  end
end