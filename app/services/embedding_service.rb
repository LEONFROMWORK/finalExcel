# frozen_string_literal: true

require "net/http"
require "json"

class EmbeddingService
  OPENAI_API_URL = "https://api.openai.com/v1/embeddings"
  MODEL = "text-embedding-3-small"
  DIMENSIONS = 1536

  def initialize(api_key = nil)
    @api_key = api_key || ENV["OPENAI_API_KEY"]

    if @api_key.blank?
      Rails.logger.error "No OpenAI API key configured for embeddings"
      raise "OpenAI API key is required for embedding generation"
    end
  end

  def generate_embedding(text)
    return nil if text.blank?

    # Clean and truncate text
    cleaned_text = text.strip.gsub(/\s+/, " ").truncate(8000)

    begin
      response = make_api_request(cleaned_text)

      if response["data"] && response["data"][0] && response["data"][0]["embedding"]
        # Track API usage
        if response["usage"] && response["usage"]["total_tokens"]
          ApiUsageTracker.track_usage(
            service: "openai_embedding",
            model: MODEL,
            tokens: response["usage"]["total_tokens"],
            metadata: {
              text_length: cleaned_text.length,
              dimensions: DIMENSIONS
            }
          )
        else
          # Estimate tokens if not provided
          ApiUsageTracker.track_embedding(cleaned_text, MODEL)
        end

        response["data"][0]["embedding"]
      else
        Rails.logger.error "Invalid embedding API response: #{response.inspect}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Embedding generation failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end

  def generate_embeddings_batch(texts)
    texts.map { |text| generate_embedding(text) }
  end

  private

  def make_api_request(text)
    make_openai_request(text)
  end


  def make_openai_request(text)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      input: text,
      model: MODEL,
      dimensions: DIMENSIONS
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      raise "OpenAI API error: #{response.code} - #{response.body}"
    end
  end
end
