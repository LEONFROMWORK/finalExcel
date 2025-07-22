# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'

# 포럼 데이터 수집 서비스
class ForumScraperService
  attr_reader :url, :options
  
  SUPPORTED_FORUMS = {
    'excelforum' => {
      base_url: 'https://www.excelforum.com',
      list_selector: 'div.discussion-list-item',
      title_selector: 'h3.discussion-title a',
      content_selector: 'div.post-content',
      pagination_selector: 'a.page-next'
    },
    'mrexcel' => {
      base_url: 'https://www.mrexcel.com/board',
      list_selector: 'div.structItem',
      title_selector: 'div.structItem-title a',
      content_selector: 'article.message-body',
      pagination_selector: 'a.pageNav-jump--next'
    }
  }.freeze
  
  def initialize(forum_type, options = {})
    @forum_type = forum_type
    @forum_config = SUPPORTED_FORUMS[forum_type]
    @options = options
    @collected_items = []
  end
  
  def scrape_test(test_url = nil)
    # 테스트용 - 단일 페이지만 수집
    url = test_url || "#{@forum_config[:base_url]}/forums/excel-questions/"
    
    begin
      puts "테스트 수집 시작: #{url}"
      
      # HTTP 요청 헤더 설정
      html = URI.open(url, 
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.5'
      ).read
      
      doc = Nokogiri::HTML(html)
      
      # 게시글 목록 추출
      posts = doc.css(@forum_config[:list_selector])
      
      puts "발견된 게시글 수: #{posts.count}"
      
      # 상위 5개만 테스트
      test_results = []
      posts.first(5).each_with_index do |post, index|
        title = post.css(@forum_config[:title_selector]).text.strip
        link = post.css(@forum_config[:title_selector]).first&.attr('href')
        
        # 상대 경로 처리
        full_link = link&.start_with?('http') ? link : "#{@forum_config[:base_url]}#{link}"
        
        result = {
          index: index + 1,
          title: title,
          link: full_link,
          scraped_at: Time.current
        }
        
        # 첫 번째 게시글의 내용도 가져오기
        if index == 0 && full_link
          begin
            content = scrape_post_content(full_link)
            result[:content_preview] = content.first(200) + "..." if content
          rescue => e
            result[:content_error] = e.message
          end
        end
        
        test_results << result
      end
      
      {
        success: true,
        url: url,
        forum_type: @forum_type,
        results_count: test_results.count,
        results: test_results
      }
      
    rescue => e
      {
        success: false,
        url: url,
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
    end
  end
  
  def scrape_post_content(post_url)
    html = URI.open(post_url,
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    ).read
    
    doc = Nokogiri::HTML(html)
    
    # 게시글 내용 추출
    content_elements = doc.css(@forum_config[:content_selector])
    content_elements.map(&:text).join("\n").strip
  end
  
  def scrape_and_save(max_pages: 1)
    results = {
      total_scraped: 0,
      total_saved: 0,
      errors: []
    }
    
    base_url = @options[:start_url] || "#{@forum_config[:base_url]}/forums/excel-questions/"
    current_url = base_url
    pages_scraped = 0
    
    while current_url && pages_scraped < max_pages
      begin
        puts "수집 중: #{current_url} (페이지 #{pages_scraped + 1}/#{max_pages})"
        
        html = URI.open(current_url,
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ).read
        
        doc = Nokogiri::HTML(html)
        posts = doc.css(@forum_config[:list_selector])
        
        posts.each do |post|
          title = post.css(@forum_config[:title_selector]).text.strip
          link = post.css(@forum_config[:title_selector]).first&.attr('href')
          full_link = link&.start_with?('http') ? link : "#{@forum_config[:base_url]}#{link}"
          
          # 실제 게시글 내용 수집
          if full_link
            begin
              sleep(1) # 서버 부하 방지
              content = scrape_post_content(full_link)
              
              if title.present? && content.present?
                # Q&A 형식으로 저장
                qa_pair = save_as_qa(title, content, full_link)
                results[:total_saved] += 1 if qa_pair
              end
              
              results[:total_scraped] += 1
            rescue => e
              results[:errors] << { url: full_link, error: e.message }
            end
          end
        end
        
        # 다음 페이지 찾기
        next_link = doc.css(@forum_config[:pagination_selector]).first&.attr('href')
        current_url = next_link ? "#{@forum_config[:base_url]}#{next_link}" : nil
        pages_scraped += 1
        
        # 과도한 요청 방지
        sleep(2)
        
      rescue => e
        results[:errors] << { url: current_url, error: e.message }
        break
      end
    end
    
    results
  end
  
  private
  
  def save_as_qa(title, content, source_url)
    # 제목을 질문으로, 내용을 답변으로 변환
    question = clean_text(title)
    answer = clean_text(content)
    
    # 너무 짧은 내용은 제외
    return nil if question.length < 10 || answer.length < 20
    
    # 중복 체크
    existing = KnowledgeBase::QaPair.where(question: question).first
    return existing if existing
    
    # 저장
    KnowledgeBase::QaPair.create!(
      question: question,
      answer: answer,
      source: @forum_type,
      metadata: {
        source_url: source_url,
        scraped_at: Time.current,
        forum_type: @forum_type
      }
    )
  rescue => e
    Rails.logger.error "Failed to save Q&A: #{e.message}"
    nil
  end
  
  def clean_text(text)
    # HTML 태그 제거 및 정리
    text.gsub(/\s+/, ' ')
        .strip
        .gsub(/\[CODE\].*?\[\/CODE\]/mi, '[코드 예제]')
        .first(5000) # 최대 5000자
  end
end