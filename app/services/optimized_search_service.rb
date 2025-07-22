# frozen_string_literal: true

class OptimizedSearchService
  attr_reader :query, :options
  
  DEFAULT_OPTIONS = {
    limit: 10,
    mode: :hybrid, # :semantic, :text, :hybrid
    quality_threshold: 0.7,
    similarity_threshold: 0.8,
    rerank: true
  }.freeze
  
  def initialize(query, options = {})
    @query = query
    @options = DEFAULT_OPTIONS.merge(options)
  end
  
  def search
    case options[:mode]
    when :semantic
      semantic_search
    when :text
      text_search
    when :hybrid
      hybrid_search
    else
      raise ArgumentError, "Invalid search mode: #{options[:mode]}"
    end
  end
  
  private
  
  def semantic_search
    embedding = generate_embedding
    return [] unless embedding
    
    results = KnowledgeBase::QaPair.search_similar(
      embedding, 
      limit: options[:limit] * 2, # Get more for reranking
      threshold: options[:quality_threshold]
    )
    
    rerank_results(results)
  end
  
  def text_search
    KnowledgeBase::QaPair
      .search_by_text(query)
      .where("quality_score >= ?", options[:quality_threshold])
      .limit(options[:limit])
  end
  
  def hybrid_search
    # Get both semantic and text results
    embedding = generate_embedding
    
    semantic_results = if embedding
      KnowledgeBase::QaPair.search_similar(
        embedding,
        limit: options[:limit],
        threshold: options[:quality_threshold]
      )
    else
      []
    end
    
    text_results = KnowledgeBase::QaPair
      .search_by_text(query)
      .where("quality_score >= ?", options[:quality_threshold])
      .limit(options[:limit])
      .to_a
    
    # Combine and deduplicate
    combined_results = (semantic_results + text_results).uniq(&:id)
    
    # Rerank combined results
    rerank_results(combined_results)
  end
  
  def generate_embedding
    Rails.cache.fetch("embedding:#{Digest::MD5.hexdigest(query)}", expires_in: 1.hour) do
      embedding_service = EmbeddingService.new
      embedding_service.generate_embedding(query)
    end
  end
  
  def rerank_results(results)
    return results unless options[:rerank]
    
    # Score based on multiple factors
    scored_results = results.map do |result|
      score = calculate_relevance_score(result)
      { result: result, score: score }
    end
    
    # Sort by score and return top results
    scored_results
      .sort_by { |item| -item[:score] }
      .first(options[:limit])
      .map { |item| item[:result] }
  end
  
  def calculate_relevance_score(result)
    score = 0.0
    
    # Quality score weight
    score += result.quality_score * 0.3
    
    # Usage count weight (normalized)
    max_usage = 1000.0 # Assume max usage count
    normalized_usage = [result.usage_count / max_usage, 1.0].min
    score += normalized_usage * 0.2
    
    # Text similarity weight
    text_similarity = calculate_text_similarity(result)
    score += text_similarity * 0.3
    
    # Recency weight
    days_old = (Time.current - result.created_at) / 1.day
    recency_score = 1.0 / (1.0 + days_old / 365.0) # Decay over a year
    score += recency_score * 0.2
    
    score
  end
  
  def calculate_text_similarity(result)
    # Simple text similarity based on keyword overlap
    query_keywords = query.downcase.split(/\W+/).uniq
    result_keywords = (result.question + ' ' + result.answer).downcase.split(/\W+/).uniq
    
    intersection = query_keywords & result_keywords
    return 0.0 if query_keywords.empty?
    
    intersection.size.to_f / query_keywords.size
  end
end