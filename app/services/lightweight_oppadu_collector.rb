# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'nokogiri'

# Lightweight Oppadu collector using HTTP requests instead of Selenium
# Fallback for when Selenium times out
class LightweightOppaduCollector
  def initialize(options = {})
    @options = options
    @base_url = 'https://www.oppadu.com'
    @community_url = "#{@base_url}/community/question/"
  end

  def collect_data(limit = 10)
    results = []
    page = 1
    max_pages = 5
    
    Rails.logger.info "Starting lightweight Oppadu collection (limit: #{limit})"
    
    while results.size < limit && page <= max_pages
      begin
        # Fetch page
        url = page > 1 ? "#{@community_url}?pg=#{page}" : @community_url
        html = fetch_page(url)
        
        doc = Nokogiri::HTML(html)
        posts = doc.css('.post-item-modern')
        
        Rails.logger.info "Found #{posts.size} posts on page #{page}"
        
        # Extract answered posts
        posts.each do |post|
          break if results.size >= limit
          
          # Check for answer badge
          next unless post.css('.answer-complete-badge').any?
          
          # Extract basic info
          link_elem = post.css('a').first
          next unless link_elem
          
          title = link_elem.text.strip
          href = link_elem['href']
          full_url = href.start_with?('http') ? href : @base_url + href
          
          # Fetch detail page
          begin
            detail_html = fetch_page(full_url)
            detail = extract_qa_from_html(detail_html, title, full_url)
            
            if detail
              results << detail
              Rails.logger.info "Collected: #{title}"
            end
          rescue => e
            Rails.logger.error "Failed to collect details: #{e.message}"
          end
          
          # Rate limit
          sleep(1)
        end
        
        page += 1
        
      rescue => e
        Rails.logger.error "Page fetch error: #{e.message}"
        break
      end
    end
    
    {
      success: true,
      platform: 'oppadu',
      results: results,
      collection_method: 'lightweight_http',
      message: "Collected #{results.size} items using lightweight method"
    }
  rescue => e
    {
      success: false,
      platform: 'oppadu',
      results: [],
      error: "Lightweight collection failed: #{e.message}"
    }
  end
  
  private
  
  def fetch_page(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    request['Accept-Language'] = 'ko-KR,ko;q=0.9'
    
    response = http.request(request)
    
    if response.code == '200'
      response.body
    else
      raise "HTTP Error: #{response.code}"
    end
  end
  
  def extract_qa_from_html(html, title, url)
    doc = Nokogiri::HTML(html)
    
    # Extract question
    question_elem = doc.css('.post-content').first
    return nil unless question_elem
    question = question_elem.text.strip
    
    # Extract selected answer
    answer_elem = doc.css('.comment-wrapper.selected-answer .comment-body').first
    return nil unless answer_elem
    answer = clean_text(answer_elem.text)
    
    # Extract images (simplified - just URLs)
    images = []
    has_base64 = false
    
    doc.css('.post-content img, .comment-wrapper.selected-answer .comment-body img').each do |img|
      src = img['src']
      if src
        if src.start_with?('data:image')
          has_base64 = true
          Rails.logger.info "Skipping post with base64 image: #{title}"
          break
        end
        images << { url: src, context: 'lightweight' }
      end
    end
    
    # base64 이미지가 있으면 nil 반환
    return nil if has_base64
    
    {
      title: title,
      question: question,
      answer: answer,
      link: url,
      tags: ['excel', 'korean'],
      source: 'oppadu',
      images: images,
      metadata: {
        collection_method: 'lightweight_http',
        has_images: images.any?
      }
    }
  end
  
  def clean_text(text)
    return '' if text.nil?
    
    # Remove excessive whitespace and normalize
    text.strip
        .gsub(/\s+/, ' ')           # Replace multiple spaces with single space
        .gsub(/\n\s*\n/, "\n\n")    # Replace multiple newlines with double newline
        .gsub(/&nbsp;/, ' ')        # Replace HTML non-breaking spaces
        .gsub(/&lt;/, '<')          # Replace HTML entities
        .gsub(/&gt;/, '>')
        .gsub(/&amp;/, '&')
        .gsub(/&quot;/, '"')
        .gsub(/&#39;/, "'")
        .strip
  end
end
