# frozen_string_literal: true

require "selenium-webdriver"
require "set"

##
# 간단한 Selenium 기반 Oppadu 수집기
class SimpleSeleniumOppaduCollector
  def initialize(options = {})
    @options = {
      limit: 10,
      headless: true
    }.merge(options)

    @base_url = "https://www.oppadu.com"
    @community_url = "#{@base_url}/community/question/"
  end

  def collect_data(limit = nil)
    limit ||= @options[:limit]

    # 간단한 Chrome 옵션
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new") if @options[:headless]
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1920,1080")

    driver = Selenium::WebDriver.for(:chrome, options: options)
    results = []

    begin
      Rails.logger.info "Navigating to Oppadu..."
      driver.get(@community_url)
      sleep(3) # 페이지 로드 대기

      # 답변된 게시글 찾기
      posts = driver.find_elements(css: ".post-item-modern")
      Rails.logger.info "Found #{posts.size} posts"

      # 먼저 답변된 게시글의 링크를 수집
      answered_posts = []
      posts.each do |post|
        begin
          # 답변 완료 배지 확인
          post.find_element(css: ".answer-complete-badge")

          # 링크와 제목 추출
          link_elem = post.find_element(css: "a")
          title = link_elem.text.strip
          href = link_elem.attribute("href")

          next if title.empty? || href.nil?

          # 전체 URL 구성
          full_url = href.start_with?("http") ? href : @base_url + href
          full_url = @community_url + href if href.start_with?("?")

          answered_posts << { title: title, url: full_url }
          Rails.logger.info "Found answered post: #{title}"

          break if answered_posts.size >= limit
        rescue Selenium::WebDriver::Error::NoSuchElementError
          # 답변 배지가 없으면 건너뛰기
          next
        end
      end

      # 수집한 링크들을 방문
      answered_posts.each do |post_info|
        begin
          # 상세 페이지 방문
          driver.get(post_info[:url])
          sleep(2)

          # 질문과 답변 추출
          question = driver.find_element(css: ".post-content").text.strip rescue ""

          # 선택된 답변만 추출
          begin
            answer_elem = driver.find_element(css: ".comment-wrapper.selected-answer .comment-text")
            answer = answer_elem.text.strip
            Rails.logger.info "Found selected answer with #{answer.length} chars"
          rescue => e
            # 선택된 답변이 없으면 건너뛰기
            Rails.logger.info "No selected answer found: #{e.message}"
            next
          end

          # 이미지 추출
          images = []

          # 질문 이미지
          question_imgs = driver.find_elements(css: ".post-content img")
          question_imgs.each do |img|
            src = img.attribute("src")
            images << { url: src, context: "question" } if src
          end

          # 답변 이미지
          answer_imgs = driver.find_elements(css: ".comment-wrapper.selected-answer img")
          answer_imgs.each do |img|
            src = img.attribute("src")
            images << { url: src, context: "answer" } if src
          end

          # 결과 저장
          results << {
            title: post_info[:title],
            question: question,
            answer: answer,
            link: post_info[:url],
            tags: [ "excel", "korean" ],
            source: "oppadu",
            images: images,
            metadata: {
              has_images: images.any?,
              scraping_method: "selenium"
            }
          }

          Rails.logger.info "Collected: #{post_info[:title]}"

        rescue => e
          Rails.logger.error "Failed to collect #{post_info[:url]}: #{e.message}"
          next
        end
      end

      {
        success: true,
        platform: "oppadu",
        results: results,
        collection_method: "selenium",
        message: "Collected #{results.size} items from Oppadu"
      }

    rescue => e
      Rails.logger.error "Selenium error: #{e.message}"
      {
        success: false,
        platform: "oppadu",
        results: [],
        error: "Selenium error: #{e.message}"
      }
    ensure
      driver&.quit
    end
  end
end
