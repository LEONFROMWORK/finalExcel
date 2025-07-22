# frozen_string_literal: true

require_relative 'resilient_scraper'
require 'nokogiri'

# Resilient Oppadu collector using circuit breaker and auto-throttle
class ResilientOppaduCollector
  def initialize(options = {})
    @options = options
    @base_url = 'https://www.oppadu.com'
    @community_url = "#{@base_url}/community/question/"
    
    # Initialize resilient scraper with custom settings for Oppadu
    @scraper = ResilientScraper.new('oppadu', {
      circuit_failure_threshold: 3,    # Open circuit after 3 failures
      circuit_timeout: 120,            # Keep circuit open for 2 minutes
      target_concurrency: 1,           # Conservative for Oppadu
      min_delay: 1.0,                  # Minimum 1 second between requests
      max_delay: 15,                   # Maximum 15 seconds delay
      max_retries: 3,
      redis: Redis.new                  # Use new Redis connection
    })
  end
  
  def collect_data(limit = 10)
    results = []
    page = 1
    max_pages = 5
    consecutive_failures = 0
    
    Rails.logger.info "Starting resilient Oppadu collection (limit: #{limit})"
    Rails.logger.info "Circuit state: #{@scraper.circuit_state}"
    
    while results.size < limit && page <= max_pages
      begin
        # Fetch page using resilient scraper
        url = page > 1 ? "#{@community_url}?pg=#{page}" : @community_url
        
        html = @scraper.scrape(url) do |scrape_url|
          fetch_with_fallback(scrape_url)
        end
        
        # Parse and extract posts
        posts = extract_posts_from_html(html)
        Rails.logger.info "Found #{posts.size} posts on page #{page}"
        
        # Process each post
        posts.each do |post|
          break if results.size >= limit
          
          # Skip if no answer
          next unless post[:has_answer]
          
          # Fetch detail page
          begin
            detail_html = @scraper.scrape(post[:url]) do |scrape_url|
              fetch_with_fallback(scrape_url)
            end
            
            detail = extract_qa_from_html(detail_html, post[:title], post[:url])
            
            if detail && !has_base64_image?(detail_html)
              results << detail
              Rails.logger.info "Collected: #{post[:title]}"
            end
            
            consecutive_failures = 0
          rescue ResilientScraper::CircuitOpenError => e
            Rails.logger.error "Circuit open, stopping collection: #{e.message}"
            break
          rescue => e
            consecutive_failures += 1
            Rails.logger.error "Failed to collect post details: #{e.message}"
            
            # Stop if too many consecutive failures
            if consecutive_failures >= 3
              Rails.logger.error "Too many consecutive failures, stopping collection"
              break
            end
          end
        end
        
        page += 1
        
      rescue ResilientScraper::CircuitOpenError => e
        Rails.logger.error "Circuit breaker open: #{e.message}"
        break
      rescue => e
        Rails.logger.error "Page fetch error: #{e.message}"
        consecutive_failures += 1
        
        if consecutive_failures >= 3
          Rails.logger.error "Too many consecutive page failures, stopping"
          break
        end
      end
    end
    
    # Save results
    save_status = save_results(results) if results.any?
    
    {
      success: true,
      platform: 'oppadu',
      results: results,
      collection_method: 'resilient_scraper',
      circuit_state: @scraper.circuit_state,
      save_status: save_status,
      message: "Collected #{results.size} items using resilient scraper"
    }
  rescue => e
    {
      success: false,
      platform: 'oppadu',
      results: [],
      error: "Resilient collection failed: #{e.message}",
      circuit_state: @scraper.circuit_state
    }
  end
  
  private
  
  def fetch_with_fallback(url)
    uri = URI.parse(url)
    
    # Try with Korean headers first
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 20
    http.open_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    request['Accept-Language'] = 'ko-KR,ko;q=0.9,en;q=0.8'
    request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    request['Cache-Control'] = 'no-cache'
    request['Pragma'] = 'no-cache'
    
    response = http.request(request)
    
    # Handle different response codes
    case response.code
    when '200'
      response.body
    when '429'
      raise ResilientScraper::RateLimitError, "Rate limited (429)"
    when '403'
      # Try alternative user agent
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15'
      response = http.request(request)
      
      if response.code == '200'
        response.body
      else
        raise "Access forbidden (403) even with alternative UA"
      end
    else
      raise "HTTP Error: #{response.code}"
    end
  end
  
  def extract_posts_from_html(html)
    doc = Nokogiri::HTML(html)
    posts = []
    
    doc.css('.post-item-modern').each do |post|
      # Check for answer badge
      has_answer = post.css('.answer-complete-badge').any?
      
      # Extract link and title
      link_elem = post.css('a').first
      next unless link_elem
      
      title = link_elem.text.strip
      href = link_elem['href']
      full_url = href.start_with?('http') ? href : @base_url + href
      
      posts << {
        title: title,
        url: full_url,
        has_answer: has_answer
      }
    end
    
    posts
  end
  
  def extract_qa_from_html(html, title, url)
    doc = Nokogiri::HTML(html)
    
    # Extract question
    question_elem = doc.css('.post-content').first
    return nil unless question_elem
    question = question_elem.text.strip
    
    # Extract selected answer
    answer_elem = doc.css('.comment-wrapper.selected-answer .comment-text').first
    return nil unless answer_elem
    answer = answer_elem.text.strip
    
    # Extract images (external URLs only)
    images = []
    doc.css('.post-content img, .comment-wrapper.selected-answer img').each do |img|
      src = img['src']
      next unless src
      next if src.start_with?('data:image') # Skip base64
      
      images << { url: src, context: 'oppadu' }
    end
    
    # Process images if any
    processed_answer = answer
    if images.any?
      begin
        processor = ThreeTierImageProcessor.new
        answer_images = doc.css('.comment-wrapper.selected-answer img').map do |img|
          src = img['src']
          { url: src } if src && !src.start_with?('data:')
        end.compact
        
        processed_answer = processor.process_images_in_content(
          answer,
          answer_images,
          context_tags: ['excel', 'oppadu', 'korean']
        )
      rescue => e
        Rails.logger.error "Image processing error: #{e.message}"
      end
    end
    
    {
      title: title,
      question: question,
      answer: processed_answer,
      link: url,
      tags: ['excel', 'korean'],
      source: 'oppadu',
      images: images,
      metadata: {
        collection_method: 'resilient_scraper',
        has_images: images.any?,
        circuit_state: @scraper.circuit_state.to_s
      }
    }
  end
  
  def has_base64_image?(html)
    html.include?('data:image')
  end
  
  def save_results(results)
    date_str = Date.current.strftime('%Y%m%d')
    export_dir = Rails.root.join('tmp', 'platform_datasets')
    FileUtils.mkdir_p(export_dir)
    
    filename = "oppadu_dataset_#{date_str}.json"
    filepath = export_dir.join(filename)
    
    # Load existing data
    existing_data = if File.exist?(filepath)
      JSON.parse(File.read(filepath))
    else
      []
    end
    
    # Track duplicates
    existing_ids = Set.new(existing_data.map { |item| item['link'] })
    new_items = 0
    duplicates = 0
    
    # Add new results
    results.each do |result|
      if existing_ids.include?(result[:link])
        duplicates += 1
      else
        existing_data << result
        existing_ids.add(result[:link])
        new_items += 1
      end
    end
    
    # Save updated data
    File.write(filepath, JSON.pretty_generate(existing_data))
    
    {
      new_items: new_items,
      duplicates: duplicates,
      total_items: existing_data.size
    }
  end
end