# frozen_string_literal: true

require 'net/http'
require 'json'
require 'digest'

# AI-based embedding service using OpenRouter's text models
class AiEmbeddingService
  OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions'
  MODEL = 'openai/gpt-3.5-turbo' # Fast and cheap model for embeddings
  DIMENSIONS = 1536

  def initialize(api_key = ENV['OPENROUTER_API_KEY'])
    @api_key = api_key
  end

  def generate_embedding(text)
    return nil if text.blank? || @api_key.blank?
    
    # For now, create a deterministic fake embedding based on text
    # This ensures consistent embeddings for the same text
    create_fake_embedding(text)
  end

  def generate_embeddings_batch(texts)
    texts.map { |text| generate_embedding(text) }
  end

  private

  def create_fake_embedding(text)
    # Create a deterministic embedding based on text content
    # This is a temporary solution until we find a proper embedding API
    
    # Clean text
    cleaned = text.downcase.strip.gsub(/\s+/, ' ')
    
    # Create hash-based seed
    hash = Digest::SHA256.hexdigest(cleaned)
    seed = hash.to_i(16)
    
    # Generate deterministic random numbers
    rng = Random.new(seed)
    
    # Create embedding vector
    embedding = Array.new(DIMENSIONS) do
      # Generate values between -1 and 1 with normal distribution
      value = rng.rand * 2 - 1
      # Apply some smoothing
      Math.tanh(value * 0.5)
    end
    
    # Add some text-based features
    # Word count feature
    word_count = cleaned.split.size
    embedding[0] = Math.tanh(word_count / 100.0)
    
    # Character count feature
    char_count = cleaned.length
    embedding[1] = Math.tanh(char_count / 500.0)
    
    # Excel-specific features
    excel_keywords = %w[vlookup hlookup index match sumif countif pivot formula cell sheet workbook]
    excel_score = excel_keywords.count { |kw| cleaned.include?(kw) }
    embedding[2] = Math.tanh(excel_score / 5.0)
    
    # Error-specific features
    error_keywords = %w[error #ref #value #div/0 #n/a #name #null]
    error_score = error_keywords.count { |kw| cleaned.include?(kw) }
    embedding[3] = Math.tanh(error_score / 3.0)
    
    # Question features
    is_question = cleaned.include?('?') || cleaned.start_with?('how', 'what', 'why', 'when', 'where')
    embedding[4] = is_question ? 1.0 : -1.0
    
    # Normalize the embedding
    magnitude = Math.sqrt(embedding.map { |x| x * x }.sum)
    embedding.map { |x| x / magnitude }
  end

  def generate_ai_embedding(text)
    # Alternative: Use AI to generate semantic features
    # This would make an API call to get semantic analysis
    # Then convert the analysis to a vector
    
    uri = URI(OPENROUTER_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['HTTP-Referer'] = ENV['APP_URL'] || 'http://localhost:3000'
    request['X-Title'] = 'Excel Unified - Semantic Analysis'
    
    prompt = <<~PROMPT
      Analyze this text and provide 10 semantic features as numbers between -1 and 1:
      1. Technical complexity (-1=simple, 1=complex)
      2. Excel-specific content (-1=general, 1=excel-specific)
      3. Error-related (-1=normal operation, 1=error/problem)
      4. Question vs Statement (-1=statement, 1=question)
      5. Beginner vs Advanced (-1=beginner, 1=advanced)
      6. Formula/Function focus (-1=data/values, 1=formulas)
      7. Visual/UI related (-1=backend/logic, 1=visual/ui)
      8. Data processing (-1=single cell, 1=bulk data)
      9. Urgency (-1=exploratory, 1=urgent problem)
      10. Clarity (-1=vague, 1=clear and specific)
      
      Text: "#{text.truncate(500)}"
      
      Respond with only 10 numbers separated by commas, like: 0.5,-0.3,0.8,...
    PROMPT
    
    request.body = {
      model: MODEL,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ],
      max_tokens: 50,
      temperature: 0.1
    }.to_json

    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('choices', 0, 'message', 'content')
      
      if content
        # Parse the numbers
        features = content.strip.split(',').map(&:to_f)
        
        # Pad with zeros if needed
        while features.size < DIMENSIONS
          features << 0.0
        end
        
        # Normalize
        magnitude = Math.sqrt(features.map { |x| x * x }.sum)
        features.map { |x| x / (magnitude + 0.0001) }
      else
        nil
      end
    else
      Rails.logger.error "OpenRouter API error: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "AI embedding generation failed: #{e.message}"
    nil
  end
end