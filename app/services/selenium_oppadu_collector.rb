# frozen_string_literal: true

require 'selenium-webdriver'
require 'set'

##
# Selenium-based Oppadu Collector for Railway deployment
# Railway doesn't support Ferrum, so we use Selenium with remote WebDriver
class SeleniumOppaduCollector
  def initialize(options = {})
    @selenium_url = ENV['RAILWAY_SELENIUM_URL'] || 'http://localhost:4444/wd/hub'
    @options = {
      limit: 10,
      max_pages: 5,
      headless: true
    }.merge(options)
    
    @base_url = 'https://www.oppadu.com'
    @community_url = "#{@base_url}/community/question/"
  end

  def collect_data(limit = nil)
    limit ||= @options[:limit]
    Rails.logger.info "Starting collect_data with limit: #{limit}"
    
    driver = setup_selenium_driver
    Rails.logger.info "Driver created successfully"

    begin
      # WebDriver 속성 숨기기 JavaScript
      driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
      Rails.logger.info "WebDriver properties hidden"
      
      results = []
      seen_post_ids = Set.new
      page = 1

      Rails.logger.info "Starting Selenium Oppadu collection (limit: #{limit})"

      while results.size < limit && page <= @options[:max_pages]
        # Navigate to page
        url = page > 1 ? "#{@community_url}?board_id=&pg=#{page}" : @community_url
        Rails.logger.info "Navigating to: #{url}"
        
        begin
          driver.get(url)
          Rails.logger.info "Page loaded: #{url}"
        rescue => e
          Rails.logger.error "Failed to load page: #{e.message}"
          raise
        end
        
        # 페이지 로드 대기
        sleep(2)
        
        # 페이지가 로드되었는지 확인
        begin
          ready_state = driver.execute_script("return document.readyState")
          Rails.logger.info "Page ready state: #{ready_state}"
        rescue => e
          Rails.logger.error "Failed to check ready state: #{e.message}"
        end

        # Find answered posts
        begin
          # Wait for post list to load
          wait = Selenium::WebDriver::Wait.new(timeout: 10)
          wait.until { driver.find_element(css: '.post-list-modern') }

          # Find all posts with answer badges
          post_items = driver.find_elements(css: '.post-item-modern')
          Rails.logger.info "Found #{post_items.size} posts on page #{page}"

          answered_posts = []
          post_items.each do |item|
            begin
              # Check if has answer badge
              item.find_element(css: '.answer-complete-badge')
              
              # Get post link
              link_elem = item.find_element(css: 'a.post-title-modern, a')
              title = link_elem.text.strip
              href = link_elem.attribute('href')
              
              # Build full URL
              post_url = build_full_url(href)
              
              # Extract post ID
              post_id = post_url[/uid=(\d+)/, 1]
              next if post_id.nil? || seen_post_ids.include?(post_id)
              
              seen_post_ids.add(post_id)
              answered_posts << {
                element: item,
                url: post_url,
                title: title,
                post_id: post_id
              }
            rescue Selenium::WebDriver::Error::NoSuchElementError
              # No answer badge, skip
            end
          end

          Rails.logger.info "Found #{answered_posts.size} answered posts on page #{page}"

          # Process each answered post
          answered_posts.each do |post_info|
            break if results.size >= limit

            # Collect detailed data
            qa_data = collect_post_details(driver, post_info)
            if qa_data
              results << qa_data
              Rails.logger.info "Collected: #{post_info[:title]}"
            end

            # Rate limiting
            sleep(rand(1.0..2.5))
          end

        rescue Selenium::WebDriver::Error::TimeoutError
          Rails.logger.warn "Timeout waiting for page #{page} to load"
          break
        end

        page += 1
      end

      {
        success: true,
        platform: 'oppadu',
        results: results,
        collection_method: 'selenium',
        message: "Collected #{results.size} items from Oppadu using Selenium"
      }

    rescue => e
      Rails.logger.error "Selenium Oppadu collection error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      {
        success: false,
        platform: 'oppadu',
        results: [],
        error: "Failed to collect from Oppadu with Selenium: #{e.message}"
      }
    ensure
      driver&.quit
    end
  end

  private

  def setup_selenium_driver
    options = Selenium::WebDriver::Chrome::Options.new
    
    # Headless mode
    options.add_argument('--headless=new') if @options[:headless]
    
    # Essential options
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    
    # Window size
    options.add_argument('--window-size=1920,1080')
    
    # User agent
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36')
    
    # Anti-detection
    options.add_argument('--disable-blink-features=AutomationControlled')
    
    if ENV['RAILWAY_SELENIUM_URL'].present?
      # Remote WebDriver for Railway
      Rails.logger.info "Using remote Selenium at: #{@selenium_url}"
      Selenium::WebDriver.for(:remote, url: @selenium_url, capabilities: options)
    else
      # Local WebDriver
      Rails.logger.info "Using local Selenium WebDriver"
      Selenium::WebDriver.for(:chrome, options: options)
    end
  end

  def build_full_url(href)
    return href if href.start_with?('http')
    
    if href.start_with?('?')
      @community_url + href
    elsif href.start_with?('/')
      @base_url + href
    else
      URI.join(@community_url, href).to_s
    end
  end

  def collect_post_details(driver, post_info)
    # Navigate to post detail page
    # Navigate with retry logic
    max_retries = 3
    retry_count = 0
    
    begin
      driver.manage.timeouts.page_load = 15 # Set page load timeout
      driver.get(post_info[:url])
      
      # Wait for key elements to be present
      wait = Selenium::WebDriver::Wait.new(timeout: 10)
      wait.until { driver.find_element(css: '.post-content') }
      
    rescue Selenium::WebDriver::Error::TimeoutError => e
      retry_count += 1
      if retry_count < max_retries
        Rails.logger.warn "Page load timeout (attempt #{retry_count}/#{max_retries}), retrying..."
        sleep(retry_count * 2) # Exponential backoff
        retry
      else
        Rails.logger.error "Failed to load page after #{max_retries} attempts"
        return nil
      end
    end # Wait for content to load
    
    # Extract question content
    begin
      question_elem = driver.find_element(css: '.post-content')
      question_content = question_elem.text.strip
    rescue
      question_content = ''
    end
    
    # Extract selected answer - 선택된 답변이 있는 게시물만 처리
    begin
      answer_elem = driver.find_element(css: '.comment-wrapper.selected-answer .comment-body')
      answer_content = clean_text(answer_elem.text)
    rescue
      # 선택된 답변이 없으면 건너뛰기
      Rails.logger.info "No selected answer found for: #{post_info[:title]}"
      return nil
    end
    
    return nil if answer_content.empty?
    
    # Extract version info (optional)
    version_info = {}
    begin
      option_items = driver.find_elements(css: '.post-options-display .option-item')
      option_items.each do |item|
        label = item.find_element(css: '.option-label').text.strip rescue nil
        value = item.find_element(css: '.option-value').text.strip rescue nil
        
        if label && value
          version_info['excel_version'] = value if label.include?('엑셀')
          version_info['os_version'] = value if label.include?('OS') || label.include?('운영')
        end
      end
    rescue
      # Version info is optional
    end
    
    # 이미지 처리는 무조건 실행
    images = []
    has_base64 = false
    
    begin
      # Extract image URLs from question
      question_images = driver.find_elements(css: '.post-content img')
      question_images.each do |img|
        src = img.attribute('src')
        if src
          if src.start_with?('data:image')
            has_base64 = true
            Rails.logger.info "Skipping post with base64 image: #{post_info[:title]}"
            break
          end
          images << { url: src, context: 'question' }
        end
      end
      
      # base64 이미지가 있으면 nil 반환하여 건너뛰기
      return nil if has_base64
      
      # Extract image URLs from answer
      answer_images = driver.find_elements(css: '.comment-wrapper.selected-answer .comment-body img')
      answer_images.each do |img|
        src = img.attribute('src')
        if src
          if src.start_with?('data:image')
            has_base64 = true
            Rails.logger.info "Skipping post with base64 image in answer: #{post_info[:title]}"
            break
          end
          images << { url: src, context: 'answer' }
        end
      end
      
      # base64 이미지가 있으면 nil 반환하여 건너뛰기
      return nil if has_base64
      
    rescue
      # Image extraction is optional
    end
    
    # Navigate back
    driver.back
    sleep(1)
    
    # 이미지 처리 (3-tier 시스템 적용)
    processed_answer = answer_content
    if images.any?
      begin
        # 답변 이미지만 추출
        answer_images = images.select { |img| img[:context] == 'answer' }
        
        # 이미지가 포함된 컨텐츠 처리 - 3-tier 처리 활성화
        processor = ThreeTierImageProcessor.new
        processed_answer = processor.process_images_in_content(
          answer_content, 
          answer_images,
          context_tags: ['excel', 'oppadu', 'formula', 'korean']
        )
        Rails.logger.info "Processed #{answer_images.size} images in answer for: #{post_info[:title]}"
      rescue => e
        Rails.logger.error "Image processing error: #{e.message}"
        # 이미지 처리 실패해도 원본 답변은 유지
      end
    end
    
    # Return collected data
    {
      title: post_info[:title],
      question: question_content,
      answer: processed_answer,
      link: post_info[:url],
      tags: extract_korean_excel_tags(post_info[:title] + ' ' + question_content),
      source: 'oppadu',
      images: images,
      metadata: {
        post_id: post_info[:post_id],
        has_formulas: answer_content.include?('='),
        formula_count: answer_content.scan(/=[A-Z가-힣]+\(/).size,
        has_images: images.any?,
        content_type: 'qa',
        language: 'ko',
        country: 'KR',
        excel_version: version_info['excel_version'],
        os_version: version_info['os_version'],
        scraping_method: 'selenium',
        image_processed: images.any?
      }
    }
  rescue => e
    Rails.logger.error "Failed to collect details for #{post_info[:url]}: #{e.message}"
    nil
  end

  def extract_korean_excel_tags(text)
    tags = []
    
    # Korean Excel terms mapping
    korean_terms = {
      '함수' => 'function',
      '수식' => 'formula',
      '피벗' => 'pivot',
      '차트' => 'chart',
      '그래프' => 'graph',
      '매크로' => 'macro',
      'VBA' => 'vba',
      '필터' => 'filter',
      '정렬' => 'sort',
      '조건부서식' => 'conditional-formatting',
      '데이터' => 'data',
      '테이블' => 'table',
      '셀' => 'cell',
      '시트' => 'sheet',
      '통합문서' => 'workbook'
    }
    
    korean_terms.each do |korean, english|
      tags << english if text.include?(korean)
    end
    
    # Excel functions
    excel_functions = %w[VLOOKUP INDEX MATCH SUMIF COUNTIF IF IFERROR CONCATENATE TEXTJOIN XLOOKUP FILTER]
    excel_functions.each do |func|
      tags << func.downcase if text.include?(func)
    end
    
    # Excel versions
    tags << 'excel-365' if text.include?('365') || text.include?('엑셀365')
    tags << 'excel-2016' if text.include?('2016')
    tags << 'excel-2019' if text.include?('2019')
    tags << 'excel-2021' if text.include?('2021')
    
    tags.uniq
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