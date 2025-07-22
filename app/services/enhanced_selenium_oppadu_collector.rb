# frozen_string_literal: true

require "selenium-webdriver"

# Enhanced Selenium-based Oppadu collector with pagination
class EnhancedSeleniumOppaduCollector
  def initialize(options = {})
    @options = options
    @base_url = "https://www.oppadu.com"
    @community_url = "https://www.oppadu.com/community/question/"
  end

  def collect_data(limit)
    limit ||= @options[:limit]

    # Chrome options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new") if @options[:headless]
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1920,1080")

    driver = Selenium::WebDriver.for(:chrome, options: options)
    results = []
    all_visited_urls = Set.new

    begin
      page_num = 1

      while results.size < limit
        Rails.logger.info "Navigating to Oppadu page #{page_num}..."

        # 페이지 URL 구성 (페이지네이션)
        page_url = if page_num == 1
          @community_url
        else
          "#{@community_url}?pg=#{page_num}"
        end

      # Set timeouts
      driver.manage.timeouts.page_load = 20 # Increase page load timeout
      driver.manage.timeouts.implicit_wait = 5 # Set implicit wait

      begin
        driver.get(page_url)

        # Wait for posts to load using explicit wait
        wait = Selenium::WebDriver::Wait.new(timeout: 15)
        wait.until { driver.find_elements(css: ".post-item-modern").size > 0 }

      rescue Selenium::WebDriver::Error::TimeoutError => e
        Rails.logger.warn "Page timeout for #{page_url}, trying to continue..."
        # Try to work with whatever loaded
      end # 페이지 로드 대기

        # 답변된 게시글 찾기
        posts = driver.find_elements(css: ".post-item-modern")
        Rails.logger.info "Found #{posts.size} posts on page #{page_num}"

        # 이 페이지에 게시글이 없으면 종료
        break if posts.empty?

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

            # 이미 방문한 URL인지 확인
            next if all_visited_urls.include?(full_url)

            answered_posts << { title: title, url: full_url }
            all_visited_urls.add(full_url)
            Rails.logger.info "Found answered post: #{title}"

          rescue Selenium::WebDriver::Error::NoSuchElementError
            # 답변 배지가 없으면 건너뛰기
            next
          end
        end

        # 이 페이지에서 새로운 답변된 게시글이 없으면 다음 페이지로
        if answered_posts.empty?
          Rails.logger.info "No new answered posts on page #{page_num}, moving to next page"
          page_num += 1
          next
        end

        # 수집한 링크들을 방문
        answered_posts.each do |post_info|
          break if results.size >= limit

          begin
            driver.get(post_info[:url])
            sleep(2) # 페이지 로드 대기

            # 질문 추출
            question_elem = driver.find_element(css: ".post-content")
            question = question_elem.text.strip
            Rails.logger.info "Found question with #{question.length} chars"

            # 선택된 답변만 추출
            answer_elem = driver.find_element(css: ".comment-wrapper.selected-answer .comment-text")
            answer = answer_elem.text.strip
            Rails.logger.info "Found selected answer with #{answer.length} chars"

            # 이미지 추출
            images = []
            has_base64 = false

            # 질문 이미지
            question_imgs = driver.find_elements(css: ".post-content img")
            question_imgs.each do |img|
              src = img.attribute("src")
              if src
                if src.start_with?("data:image")
                  has_base64 = true
                  Rails.logger.info "Skipping post with base64 image: #{post_info[:title]}"
                  break
                end
                images << { url: src, context: "question" }
              end
            end

            # base64 이미지가 있으면 이 게시물 건너뛰기
            if has_base64
              next
            end

            # 답변 이미지
            answer_imgs = driver.find_elements(css: ".comment-wrapper.selected-answer img")
            answer_imgs.each do |img|
              src = img.attribute("src")
              if src
                if src.start_with?("data:image")
                  has_base64 = true
                  Rails.logger.info "Skipping post with base64 image in answer: #{post_info[:title]}"
                  break
                end
                images << { url: src, context: "answer" }
              end
            end

            # base64 이미지가 있으면 이 게시물 건너뛰기
            if has_base64
              next
            end

            # Post ID 추출 (URL에서)
            match_result = post_info[:url].match(/\d+$/)
            post_id = match_result ? match_result[0] : nil

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
                scraping_method: "selenium",
                page_number: page_num,
                post_id: post_id
              }
            }

            Rails.logger.info "Collected: #{post_info[:title]} (Total: #{results.size})"

          rescue => e
            Rails.logger.error "Failed to collect #{post_info[:url]}: #{e.message}"
            next
          end
        end

        # 다음 페이지로
        page_num += 1

        # 너무 많은 페이지를 탐색하지 않도록 제한
        if page_num > 20
          Rails.logger.info "Reached maximum page limit (20)"
          break
        end
      end

      {
        success: true,
        platform: "oppadu",
        results: results,
        collection_method: "selenium_enhanced",
        message: "Collected #{results.size} items from Oppadu (explored #{page_num - 1} pages)"
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
