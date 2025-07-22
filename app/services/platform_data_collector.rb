# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "zlib"
require "stringio"
require "nokogiri"

# Platform-specific data collector for StackOverflow, Reddit, and Oppadu
class PlatformDataCollector
  attr_reader :platform, :options

  PLATFORMS = {
    "stackoverflow" => {
      name: "Stack Overflow",
      requires_api: true,
      api_endpoint: "https://api.stackexchange.com/2.3",
      rate_limit: 300 # requests per day without key
    },
    "reddit" => {
      name: "Reddit",
      requires_api: true,
      api_endpoint: "https://www.reddit.com/r/excel",
      rate_limit: 60 # requests per minute
    },
    "oppadu" => {
      name: "오빠두 (Oppadu)",
      requires_api: false,
      base_url: "https://www.oppadu.com",
      rate_limit: 30 # requests per minute
    },
    "mrexcel" => {
      name: "Mr. Excel Forum",
      requires_api: false,
      base_url: "https://www.mrexcel.com",
      forum_path: "/board/forums/excel-questions.10/",
      rate_limit: 30 # requests per minute
    }
  }.freeze

  def initialize(platform, options = {})
    @platform = platform.to_s.downcase
    @options = options

    unless PLATFORMS.key?(@platform)
      raise ArgumentError, "Unsupported platform: #{platform}"
    end
  end

  def collect_data(limit = 10)
    result = case @platform
    when "stackoverflow"
      collect_stackoverflow_data(limit)
    when "reddit"
      collect_reddit_data(limit)
    when "oppadu"
      collect_oppadu_data(limit)
    when "mrexcel"
      collect_mrexcel_data(limit)
    else
      { success: false, error: "Platform not implemented: #{@platform}" }
    end

    # 성공적으로 수집된 경우 자동 저장 (중복 제거 및 일일 누적)
    if result[:success] && result[:results]&.any?
      saver = PlatformDataSaver.new
      save_result = saver.save_platform_data(@platform, result[:results], {
        quota_remaining: result[:quota_remaining],
        collection_method: result[:collection_method] || "api"
      })

      # 저장 결과를 원본 결과에 병합
      result[:save_status] = save_result
      result[:message] = save_result[:message] if save_result[:success]
    end

    result
  end

  private

  def collect_stackoverflow_data(limit)
    # Check if we have API credentials
    api_key = ENV["STACKOVERFLOW_API_KEY"]

    if api_key.blank?
      # Use Pipedata as fallback
      Rails.logger.info "No StackOverflow API key found, using Pipedata"
      return use_pipedata_fallback(limit)
    end

    begin
      # Stack Exchange API endpoint
      base_url = "https://api.stackexchange.com/2.3"

      # Search for Excel-related questions with accepted answers
      # 페이지당 30개씩 가져와서 모든 채택된 답변 수집
      params = {
        key: api_key,
        site: "stackoverflow",
        tagged: "excel",
        sort: "votes",
        order: "desc",
        pagesize: 30, # API 기본 제한
        has_accepted_answer: "true"
        # No filter - will get question IDs and fetch details separately
      }

      uri = URI("#{base_url}/questions")
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        # Handle gzip encoding
        body = response.body
        if response["Content-Encoding"] == "gzip"
          body = Zlib::GzipReader.new(StringIO.new(body)).read
        end

        data = JSON.parse(body)

        if data["items"]
          results = process_stackoverflow_items(data["items"], limit)

          {
            success: true,
            platform: "stackoverflow",
            results: results,
            quota_remaining: data["quota_remaining"],
            message: "Collected #{results.size} items from Stack Overflow"
          }
        else
          { success: false, error: "No items found in response" }
        end
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: "API error: #{error_data['error_message'] || response.code}" }
      end
    rescue => e
      Rails.logger.error "Stack Overflow API error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def collect_reddit_data(limit)
    # Check if we have API credentials
    client_id = ENV["REDDIT_CLIENT_ID"]
    client_secret = ENV["REDDIT_CLIENT_SECRET"]

    if client_id.blank? || client_secret.blank?
      return {
        success: false,
        error: "Reddit API credentials not configured. Please add REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET to .env file",
        platform: "reddit",
        results: []
      }
    end

    begin
      # Get access token
      token = get_reddit_access_token(client_id, client_secret)
      return { success: false, error: "Failed to authenticate with Reddit" } unless token

      # Fetch posts from r/excel
      uri = URI("https://oauth.reddit.com/r/excel/top.json")
      params = {
        limit: limit,
        time: "week", # Top posts from this week
        raw_json: 1
      }
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["User-Agent"] = "ExcelUnified/1.0"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == "200"
        data = JSON.parse(response.body)
        results = process_reddit_posts(data["data"]["children"], token)

        {
          success: true,
          platform: "reddit",
          results: results,
          message: "Collected #{results.size} items from Reddit r/excel"
        }
      else
        { success: false, error: "Reddit API error: #{response.code}" }
      end
    rescue => e
      Rails.logger.error "Reddit API error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def collect_oppadu_data(limit)
    Rails.logger.info "Collecting Oppadu data (limit: #{limit})..."

    # Use Playwright collector as primary method
    if ENV["USE_PLAYWRIGHT_OPPADU"] != "false"
      Rails.logger.info "Using Simple Playwright collector for Oppadu"
      require_relative "simple_playwright_oppadu_collector"
      playwright = SimplePlaywrightOppaduCollector.new
      return playwright.collect_data(limit)
    end

    # Use resilient collector as secondary method
    if ENV["USE_RESILIENT_COLLECTOR"] != "false"
      Rails.logger.info "Using resilient collector with circuit breaker and auto-throttle"
      require_relative "resilient_oppadu_collector"
      resilient = ResilientOppaduCollector.new
      result = resilient.collect_data(limit)

      # If circuit is open, fall back to lightweight collector
      if result[:circuit_state] == :open
        Rails.logger.warn "Circuit breaker is open, falling back to lightweight collector"
        require_relative "lightweight_oppadu_collector"
        lightweight = LightweightOppaduCollector.new
        return lightweight.collect_data(limit)
      end

      return result
    end

    # Enhanced 버전 사용 (페이지네이션 지원)
    Rails.logger.info "Using Enhanced Selenium for Oppadu collection"

    begin
      # Try Selenium first with timeout
      Timeout.timeout(60) do # 60 second timeout
        selenium_collector = EnhancedSeleniumOppaduCollector.new({ limit: limit, headless: true })
        result = selenium_collector.collect_data(limit)

      if result[:success] && result[:results].present?
        # 이미지 처리 적용
        result[:results].each do |item|
          if item[:images].present? && item[:images].any?
            Rails.logger.info "Processing #{item[:images].size} images for: #{item[:title]}"

            # 답변 이미지만 추출
            answer_images = item[:images].select { |img| img[:context] == "answer" }

            # 3-tier 이미지 처리 적용
            if answer_images.any?
              begin
                processed_answer = ImageContentProcessor.process_images_in_content(
                  item[:answer],
                  answer_images,
                  use_advanced_processing: true,
                  context_tags: [ "excel", "oppadu", "formula" ]
                )
                item[:answer] = processed_answer
                Rails.logger.info "Processed #{answer_images.size} answer images with 3-tier processing"
              rescue => e
                Rails.logger.error "Image processing error: #{e.message}"
              end
            end
          end
        end

        return result
      else
        return {
          success: false,
          platform: "oppadu",
          results: [],
          error: "Selenium collection returned no results"
        }
      end
      end # End of Timeout block
    rescue Timeout::Error => e
      Rails.logger.warn "Selenium timeout for Oppadu, using lightweight collector"
      # Fallback to lightweight collector
      begin
        require_relative "lightweight_oppadu_collector"
        lightweight = LightweightOppaduCollector.new
        lightweight.collect_data(limit)
      rescue => fallback_error
        Rails.logger.error "Lightweight collector also failed: #{fallback_error.message}"
        # Final fallback to nokogiri method
        collect_oppadu_data_with_nokogiri(limit)
      end
    rescue => e
      Rails.logger.error "Selenium collection failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      {
        success: false,
        platform: "oppadu",
        results: [],
        error: "Selenium collection error: #{e.message}"
      }
    end
  end


  def collect_oppadu_data_with_nokogiri(limit)
    begin
      require "nokogiri"
      require "open-uri"

      base_url = PLATFORMS["oppadu"][:base_url]
      community_url = "#{base_url}/community/question/"

      results = []
      seen_post_ids = Set.new  # 중복 방지를 위한 post ID 추적
      page = 1
      max_pages = 5  # 최대 5페이지까지만 수집

      while results.size < limit && page <= max_pages
        begin
          # 페이지 URL 구성 - 오빠두는 pg 파라미터 사용
          page_url = page > 1 ? "#{community_url}?board_id=&pg=#{page}" : community_url

          Rails.logger.info "Fetching Oppadu page #{page}: #{page_url}"

          # Add headers to appear as a regular browser
          html = URI.open(page_url,
            "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language" => "ko-KR,ko;q=0.9,en;q=0.8",
            "Referer" => base_url,
            "DNT" => "1",
            "Connection" => "keep-alive",
            "Upgrade-Insecure-Requests" => "1"
          ).read

          doc = Nokogiri::HTML(html)

          # post-list-modern 컨테이너 찾기
          post_list = doc.css(".post-list-modern").first
          if post_list.nil?
            Rails.logger.warn "No post-list-modern container found on page #{page}"
            break
          end

          # 답변 완료된 게시글만 수집
          answered_posts = []
          post_items = post_list.css(".post-item-modern")

          Rails.logger.info "Found #{post_items.size} posts on page #{page}"

          post_items.each do |item|
            # answer-complete-badge가 있는지 확인 (mob-hidden 포함)
            has_answer = item.css(".answer-complete-badge.mob-hidden").any? || item.css(".answer-complete-badge").any?
            next unless has_answer

            # 게시글 링크 추출
            link_elem = item.css("a.post-title-modern").first || item.css("a[href]").first
            next unless link_elem

            href = link_elem["href"]
            next unless href

            # URL 구성
            post_url = if href.start_with?("?")
              community_url + href
            elsif href.start_with?("/")
              base_url + href
            elsif href.start_with?("http")
              href
            else
              URI.join(community_url, href).to_s
            end

            # 유효한 게시글 URL인지 확인
            next unless post_url.include?("board_id=") && post_url.include?("action=view") && post_url.include?("uid=")

            # Post ID 추출
            post_id = extract_oppadu_post_id(post_url)
            next if post_id.nil? || seen_post_ids.include?(post_id)

            seen_post_ids.add(post_id)

            # 제목 추출
            title = link_elem.text.strip
            next if title.empty?

            answered_posts << {
              url: post_url,
              title: title,
              post_id: post_id
            }
          end

          Rails.logger.info "Found #{answered_posts.size} answered posts on page #{page}"

          # 각 답변된 게시글의 상세 내용 수집
          answered_posts.each do |post_info|
            break if results.size >= limit

            begin
              # Rate limiting
              sleep(rand(1.0..3.0))

              # 상세 페이지 가져오기
              post_html = URI.open(post_info[:url],
                "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept-Language" => "ko-KR,ko;q=0.9",
                "Referer" => page_url
              ).read

              post_doc = Nokogiri::HTML(post_html)

              # 질문 내용 추출
              question_content = post_doc.css(".post-content").first&.text&.strip || ""

              # 선택된 답변 추출 (comment-wrapper selected-answer)
              selected_answer = nil
              selected_answer_elem = post_doc.css(".comment-wrapper.selected-answer").first
              if selected_answer_elem
                # 답변 내용 추출 (comment-content 내부)
                answer_content = selected_answer_elem.css(".comment-content").first
                if answer_content
                  # 답변자 정보 제거하고 순수 답변 내용만 추출
                  answer_clone = answer_content.clone
                  answer_clone.css(".comment-author, .comment-meta").remove
                  selected_answer = answer_clone.text.strip
                end
              end

              # 답변이 없으면 첫 번째 댓글 사용
              if selected_answer.nil? || selected_answer.empty?
                first_comment = post_doc.css(".comment-wrapper .comment-content").first
                if first_comment
                  comment_clone = first_comment.clone
                  comment_clone.css(".comment-author, .comment-meta").remove
                  selected_answer = comment_clone.text.strip
                end
              end

              next if selected_answer.nil? || selected_answer.empty?

              # 버전 정보 추출
              version_info = {}
              options_container = post_doc.css(".post-options-display .options-container").first
              if options_container
                option_items = options_container.css(".option-item")
                option_items.each do |item|
                  label = item.css(".option-label").first&.text&.strip
                  value = item.css(".option-value").first&.text&.strip

                  if label && value
                    version_info["excel_version"] = value if label.include?("엑셀")
                    version_info["os_version"] = value if label.include?("OS") || label.include?("운영")
                  end
                end
              end

              # 이미지 추출 - 질문과 답변 분리 (조건부)
              # 이미지 처리는 무조건 실행
              question_images = ImageContentProcessor.extract_images_from_html(
                post_doc.css(".post-content").first&.to_html || "",
                post_info[:url]
              )

              answer_images = if selected_answer_elem
                ImageContentProcessor.extract_images_from_html(
                  selected_answer_elem.to_html,
                  post_info[:url]
                )
              else
                []
              end

              all_images = question_images + answer_images

              # base64 이미지가 있으면 이 게시물 건너뛰기
              if all_images.any? { |img| img[:url]&.start_with?("data:image") }
                Rails.logger.info "Skipping post with base64 image: #{post_info[:title]}"
                next
              end

              # 이미지가 포함된 답변 처리 - 3-tier 처리 활성화
              processed_answer = ImageContentProcessor.process_images_in_content(
                selected_answer,
                answer_images,
                use_advanced_processing: true,
                context_tags: [ "excel", "oppadu", "formula", "korean" ]
              )

              # 결과 저장
              results << {
                title: post_info[:title],
                question: question_content,
                answer: processed_answer,
                link: post_info[:url],
                tags: extract_korean_excel_tags(post_info[:title] + " " + question_content),
                source: "oppadu",
                images: all_images,
                metadata: {
                  post_id: post_info[:post_id],
                  has_formulas: processed_answer.include?("="),
                  formula_count: processed_answer.scan(/=[A-Z가-힣]+\(/).size,
                  has_images: all_images.any?,
                  content_type: "qa",
                  language: "ko",
                  country: "KR",
                  excel_version: version_info["excel_version"],
                  os_version: version_info["os_version"],
                  scraping_method: "nokogiri"
                }
              }

              Rails.logger.info "Collected: #{post_info[:title]}"

            rescue => e
              Rails.logger.error "Failed to fetch post detail #{post_info[:url]}: #{e.message}"
            end
          end

          # 다음 페이지로
          page += 1

          # 페이지 간 지연
          sleep(rand(2.0..5.0))

        rescue => e
          Rails.logger.error "Failed to fetch Oppadu page #{page}: #{e.message}"
          break
        end
      end

      {
        success: true,
        platform: "oppadu",
        results: results,
        collection_method: "nokogiri_fallback",
        message: "Collected #{results.size} unique Q&A items from Oppadu using Nokogiri"
      }

    rescue => e
      Rails.logger.error "Oppadu scraping error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      {
        success: false,
        error: "Failed to scrape Oppadu: #{e.message}",
        platform: "oppadu",
        results: []
      }
    end
  end

  def extract_oppadu_post_id(url)
    # Extract uid parameter from URL
    match = url.match(/uid=(\d+)/)
    match ? match[1] : nil
  end

  def extract_image_context(img_element)
    # 이미지 주변 텍스트에서 컨텍스트 추출
    parent = img_element.parent
    context = []

    # 이미지 앞뒤 텍스트 수집
    if parent
      prev_text = parent.previous_sibling&.text&.strip
      next_text = parent.next_sibling&.text&.strip

      context << prev_text if prev_text.present? && prev_text.length < 100
      context << next_text if next_text.present? && next_text.length < 100
    end

    # 테이블 내 이미지인 경우
    if img_element.ancestors("table").any?
      context << "테이블 내 이미지"
    end

    context.join(" - ").presence || "엑셀 관련 이미지"
  end

  def process_answer_with_images(answer_text, images)
    return answer_text if images.empty?

    # 이미지 설명을 답변에 추가
    processed_answer = answer_text

    # Base64 이미지가 있는 경우 설명 추가
    base64_images = images.select { |img| img[:type] == "base64" }
    if base64_images.any?
      image_descriptions = base64_images.map { |img| img[:description] }.join(", ")
      processed_answer += "\n\n[첨부 이미지: #{image_descriptions}]"
    end

    # 외부 이미지가 있는 경우 설명 추가
    external_images = images.select { |img| img[:type] == "external" }
    if external_images.any?
      external_descriptions = external_images.map { |img| img[:description] }.join(", ")
      processed_answer += "\n\n[참조 이미지: #{external_descriptions}]"
    end

    processed_answer
  end

  def collect_mrexcel_data(limit)
    begin
      require "nokogiri"
      require "open-uri"

      base_url = PLATFORMS["mrexcel"][:base_url]
      forum_path = PLATFORMS["mrexcel"][:forum_path]

      # Fetch the forum page
      uri = URI.join(base_url, forum_path)

      # Add headers to appear as a regular browser
      html = URI.open(uri,
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.5"
      ).read

      doc = Nokogiri::HTML(html)

      # Find solved threads (has a checkmark or "Solved" indicator)
      threads = []
      thread_items = doc.css(".structItem")

      thread_items.each_with_index do |item, index|
        break if threads.size >= limit

        # Check if thread is solved
        is_solved = item.css(".structItem-status--solved").any? ||
                   item.css(".labelLink").any? { |label| label.text.downcase.include?("solved") }

        next unless is_solved

        # Extract thread info
        title_elem = item.css(".structItem-title a").first
        next unless title_elem

        thread_url = title_elem["href"]
        thread_url = URI.join(base_url, thread_url).to_s unless thread_url.start_with?("http")

        thread_title = title_elem.text.strip

        # Add rate limiting
        sleep(2) if index > 0

        # Fetch thread details
        thread_data = fetch_mrexcel_thread(thread_url)
        next unless thread_data

        threads << thread_data.merge(
          title: thread_title,
          link: thread_url,
          source: "mrexcel"
        )
      end

      {
        success: true,
        platform: "mrexcel",
        results: threads,
        message: "Collected #{threads.size} solved threads from MrExcel"
      }

    rescue => e
      Rails.logger.error "MrExcel scraping error: #{e.message}"
      {
        success: false,
        error: "Failed to scrape MrExcel: #{e.message}",
        platform: "mrexcel",
        results: []
      }
    end
  end

  def use_pipedata_fallback(limit)
    # Use existing Pipedata importer
    importer = PipedataImporter.new
    result = importer.import_excel_qa

    if result[:success]
      {
        success: true,
        platform: "stackoverflow",
        source: "pipedata_fallback",
        results: [], # Pipedata imports directly, doesn't return results
        message: "Imported #{result[:imported]} items from Pipedata (StackOverflow local database)"
      }
    else
      {
        success: false,
        error: result[:error],
        platform: "stackoverflow",
        results: []
      }
    end
  end

  def process_stackoverflow_items(items, limit)
    results = []

    # 각 페이지의 모든 채택된 답변을 수집 (limit까지)
    items.each do |item|
      # Get accepted answer if exists - 채택된 답변만!
      next unless item["accepted_answer_id"]

      # Fetch full question details with body
      full_question = fetch_stackoverflow_question(item["question_id"])
      next unless full_question

      # Fetch answer details
      answer = fetch_stackoverflow_answer(item["accepted_answer_id"])
      next unless answer

      # Get full body without truncation
      question_body = full_question["body"] || item["title"]
      answer_body = answer["body"] || ""

      # 이미지 추출
      question_images = ImageContentProcessor.extract_images_from_html(question_body, item["link"])
      answer_images = ImageContentProcessor.extract_images_from_html(answer_body, item["link"])
      all_images = question_images + answer_images

      # 이미지가 포함된 컨텐츠 처리
      processed_question = clean_html(question_body)
      processed_answer = clean_html(answer_body)
      processed_answer = ImageContentProcessor.process_images_in_content(
        processed_answer,
        answer_images,
        use_advanced_processing: true,
        context_tags: [ "excel", "stackoverflow" ]
      )

      results << {
        title: item["title"],
        question: processed_question,
        answer: processed_answer,
        link: item["link"],
        tags: item["tags"] || [],
        score: item["score"],
        source: "stackoverflow",
        images: all_images,
        metadata: {
          question_id: item["question_id"],
          answer_id: answer["answer_id"],
          question_score: item["score"],
          answer_score: answer["score"],
          creation_date: item["creation_date"],
          last_activity_date: item["last_activity_date"],
          answer_length: processed_answer.length,
          has_images: all_images.any?,
          has_accepted_answer: true
        }
      }

      # limit에 도달하면 중단
      break if results.size >= limit
    end

    results
  end

  def fetch_stackoverflow_question(question_id)
    api_key = ENV["STACKOVERFLOW_API_KEY"]
    base_url = "https://api.stackexchange.com/2.3"

    # Use filter that includes body
    params = {
      key: api_key,
      site: "stackoverflow",
      filter: "!9Z(-wzu0T" # Includes body
    }

    uri = URI("#{base_url}/questions/#{question_id}")
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      # Handle gzip encoding
      body = response.body
      if response["Content-Encoding"] == "gzip"
        body = Zlib::GzipReader.new(StringIO.new(body)).read
      end

      data = JSON.parse(body)
      data["items"]&.first
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to fetch question #{question_id}: #{e.message}"
    nil
  end

  def fetch_stackoverflow_answer(answer_id)
    api_key = ENV["STACKOVERFLOW_API_KEY"]
    base_url = "https://api.stackexchange.com/2.3"

    params = {
      key: api_key,
      site: "stackoverflow",
      filter: "!9Z(-wzu0T" # Include body
    }

    uri = URI("#{base_url}/answers/#{answer_id}")
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      # Handle gzip encoding
      body = response.body
      if response["Content-Encoding"] == "gzip"
        body = Zlib::GzipReader.new(StringIO.new(body)).read
      end

      data = JSON.parse(body)
      data["items"]&.first
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to fetch answer #{answer_id}: #{e.message}"
    nil
  end

  def clean_html(text)
    # Preserve code blocks before processing
    preserved_code = {}
    code_counter = 0

    # Preserve code blocks
    text = text.gsub(/<pre[^>]*><code[^>]*>(.*?)<\/code><\/pre>/m) do |match|
      code_counter += 1
      key = "[[CODE_BLOCK_#{code_counter}]]"
      preserved_code[key] = $1.gsub(/<[^>]+>/, "").gsub(/&lt;/, "<").gsub(/&gt;/, ">")
      "\n#{key}\n"
    end

    # Preserve inline code
    text = text.gsub(/<code[^>]*>(.*?)<\/code>/) do |match|
      code_counter += 1
      key = "[[INLINE_CODE_#{code_counter}]]"
      preserved_code[key] = $1.gsub(/<[^>]+>/, "").gsub(/&lt;/, "<").gsub(/&gt;/, ">")
      " #{key} "
    end

    # Convert line breaks to actual newlines
    text = text.gsub(/<br\s*\/?>/, "\n")
               .gsub(/<\/p>/, "\n\n")
               .gsub(/<\/div>/, "\n")
               .gsub(/<\/li>/, "\n")

    # Remove remaining HTML tags
    text = text.gsub(/<[^>]+>/, "")

    # Decode HTML entities
    text = text.gsub(/&lt;/, "<")
               .gsub(/&gt;/, ">")
               .gsub(/&amp;/, "&")
               .gsub(/&quot;/, '"')
               .gsub(/&#39;/, "'")
               .gsub(/&nbsp;/, " ")

    # Restore preserved code blocks
    preserved_code.each do |key, code|
      text = text.gsub(key, code)
    end

    # Clean up excessive whitespace while preserving structure
    text = text.gsub(/[[:space:]]+/, " ")  # Replace multiple spaces with single space
               .gsub(/\n\s*\n\s*\n/, "\n\n")  # Max 2 consecutive newlines
               .strip

    text
  end

  def get_reddit_access_token(client_id, client_secret)
    uri = URI("https://www.reddit.com/api/v1/access_token")

    request = Net::HTTP::Post.new(uri)
    request.basic_auth(client_id, client_secret)
    request.set_form_data(
      "grant_type" => "client_credentials"
    )
    request["User-Agent"] = "ExcelUnified/1.0"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "200"
      data = JSON.parse(response.body)
      data["access_token"]
    else
      nil
    end
  end

  def process_reddit_posts(posts, token)
    results = []

    posts.each do |post_data|
      post = post_data["data"]

      # Skip if no selftext (link posts)
      next if post["selftext"].blank?

      # Get top comment as answer - 가장 높은 점수의 유효한 댓글만
      top_comment = fetch_reddit_top_comment(post["id"], token)
      next unless top_comment

      # Reddit은 HTML이 아닌 텍스트 포맷이므로 이미지 URL 추출
      question_images = extract_reddit_images(post["selftext_html"] || post["selftext"])
      answer_images = extract_reddit_images(top_comment["body_html"] || top_comment["body"])
      all_images = question_images + answer_images

      # 이미지가 포함된 답변 처리
      processed_answer = top_comment["body"]
      processed_answer = ImageContentProcessor.process_images_in_content(
        processed_answer,
        answer_images,
        use_advanced_processing: true,
        context_tags: [ "excel", "reddit" ]
      )

      results << {
        title: post["title"],
        question: post["selftext"],
        answer: processed_answer,
        link: "https://reddit.com#{post['permalink']}",
        tags: extract_excel_tags(post["title"] + " " + post["selftext"]),
        score: post["score"],
        source: "reddit",
        images: all_images,
        metadata: {
          post_id: post["id"],
          author: post["author"],
          subreddit: post["subreddit"],
          created_utc: post["created_utc"],
          num_comments: post["num_comments"],
          upvote_ratio: post["upvote_ratio"],
          has_images: all_images.any?,
          answer_score: top_comment["score"],
          is_bot_filtered: true
        }
      }
    end

    results
  end

  def extract_reddit_images(content)
    return [] unless content.present?

    images = []

    # Reddit 이미지 링크 패턴
    patterns = [
      /https?:\/\/i\.redd\.it\/[^\s]+/,
      /https?:\/\/preview\.redd\.it\/[^\s]+/,
      /https?:\/\/i\.imgur\.com\/[^\s]+/,
      /https?:\/\/imgur\.com\/[^\s]+/
    ]

    patterns.each do |pattern|
      content.scan(pattern).each do |url|
        images << {
          url: url.split("?").first, # 쿼리 파라미터 제거
          alt: "Reddit 이미지",
          type: "external",
          description: "Reddit 업로드 이미지"
        }
      end
    end

    # HTML인 경우 img 태그도 확인
    if content.include?("<img")
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
      doc.css("img").each do |img|
        src = img["src"]
        next unless src

        images << {
          url: src,
          alt: img["alt"] || "Reddit 이미지",
          type: "external",
          description: img["alt"] || "Reddit 업로드 이미지"
        }
      end
    end

    images.uniq { |img| img[:url] }
  end

  def fetch_reddit_top_comment(post_id, token)
    uri = URI("https://oauth.reddit.com/comments/#{post_id}.json")
    params = { limit: 10, sort: "best", depth: 1, raw_json: 1 }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["User-Agent"] = "ExcelUnified/1.0"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "200"
      data = JSON.parse(response.body)
      # Reddit returns array [post, comments]
      comments = data[1]["data"]["children"] rescue []

      # Filter out bot comments (AutoModerator, etc)
      valid_comments = comments.select do |c|
        comment_data = c["data"]
        body = comment_data["body"]
        author = comment_data["author"]

        # Skip deleted, removed, or bot comments
        next false if body == "[deleted]" || body == "[removed]"
        next false if author == "[deleted]" || author == "AutoModerator"

        # Skip comments that start with bot patterns
        next false if body.start_with?("/u/", "Your post was submitted successfully")
        next false if body.include?("I am a bot") || body.include?("This is an automated")

        # Must have meaningful content (more than just a link or short response)
        next false if body.strip.length < 50

        true
      end

      # Get the highest scored valid comment
      best_comment = valid_comments.max_by { |c| c["data"]["score"] || 0 }
      best_comment ? best_comment["data"] : nil
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to fetch comment for post #{post_id}: #{e.message}"
    nil
  end

  def extract_excel_tags(text)
    tags = []

    # Common Excel functions
    excel_functions = %w[VLOOKUP HLOOKUP INDEX MATCH SUMIF COUNTIF AVERAGEIF
                        XLOOKUP FILTER SORT UNIQUE PIVOT OFFSET INDIRECT]

    excel_functions.each do |func|
      tags << func if text.upcase.include?(func)
    end

    # Error types
    error_types = %w[#REF! #VALUE! #NAME? #DIV/0! #N/A #NUM! #NULL!]
    error_types.each do |error|
      tags << error.delete("#!?") if text.include?(error)
    end

    # General tags
    tags << "formula" if text.match?(/formula|function/i)
    tags << "vba" if text.match?(/vba|macro/i)
    tags << "pivot" if text.match?(/pivot/i)
    tags << "chart" if text.match?(/chart|graph/i)

    tags.uniq
  end

  def generate_question_from_title(title)
    # 튜토리얼 제목을 질문 형식으로 변환
    if title.include?("방법") || title.include?("하는법")
      title + "?"
    elsif title.include?("함수")
      "#{title}은(는) 어떻게 사용하나요?"
    elsif title.include?("오류") || title.include?("에러")
      "#{title}가 발생하는 이유와 해결 방법은?"
    else
      "엑셀에서 #{title}에 대해 설명해주세요."
    end
  end

  def generate_answer_from_content(content, formulas)
    # 콘텐츠를 답변 형식으로 정리
    answer = content

    if formulas.any?
      answer += "\n\n예제 수식:\n"
      formulas.each { |f| answer += "#{f}\n" }
    end

    answer
  end

  def extract_korean_excel_tags(text)
    tags = []

    # 한국어 엑셀 함수명
    korean_functions = %w[찾기 합계 평균 개수 최대값 최소값 조건부 피벗 매크로]
    korean_functions.each do |func|
      tags << func if text.include?(func)
    end

    # 영어 함수명도 추출
    tags += extract_excel_tags(text)

    # 오류 관련 태그
    if text.include?("오류") || text.include?("에러")
      tags << "오류해결"
    end

    tags.uniq
  end

  def fetch_mrexcel_thread(thread_url)
    begin
      html = URI.open(thread_url,
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      ).read

      doc = Nokogiri::HTML(html)

      # Get all posts in the thread
      posts = doc.css(".message-userContent")
      return nil if posts.empty?

      # First post is the question
      question_elem = posts.first
      question_text = extract_text_from_element(question_elem)

      # Find best answer (marked as solution or highest rated)
      answer_elem = nil
      answer_text = nil

      # Look for marked solution
      solution_post = doc.css(".message--solution").first
      if solution_post
        answer_elem = solution_post.css(".message-userContent").first
      else
        # Get the second post as answer if no marked solution
        answer_elem = posts[1] if posts.size > 1
      end

      return nil unless answer_elem

      answer_text = extract_text_from_element(answer_elem)

      # Extract images from both question and answer with proper processing
      question_images = ImageContentProcessor.extract_images_from_html(
        question_elem.to_html,
        thread_url
      )
      answer_images = ImageContentProcessor.extract_images_from_html(
        answer_elem.to_html,
        thread_url
      )
      all_images = question_images + answer_images

      # Extract structured content metadata
      has_vba = answer_text.include?("[VBA CODE]") || answer_text.match?(/\b(Sub|Function|End Sub|End Function)\b/i)
      has_excel_table = answer_text.include?("[EXCEL TABLE]")
      has_formulas = answer_text.match?(/`=[^`]+`/) || answer_text.include?("=")

      # Count code blocks and tables
      vba_count = answer_text.scan(/```vba/).size
      table_count = answer_text.scan(/\[EXCEL TABLE\]/).size
      formula_count = answer_text.scan(/`=[^`]+`/).size

      # Extract tags from thread labels
      tags = doc.css(".labelLink").map { |label| label.text.strip }
      tags += extract_excel_tags(question_text + " " + answer_text)

      # Add structure-based tags
      tags << "vba" if has_vba
      tags << "excel-table" if has_excel_table
      tags << "formula" if has_formulas

      # 이미지가 포함된 답변 처리
      processed_answer = ImageContentProcessor.process_images_in_content(
        answer_text,
        answer_images,
        use_advanced_processing: true,
        context_tags: [ "excel", "mrexcel" ]
      )

      {
        question: question_text,
        answer: processed_answer,
        tags: tags.uniq,
        images: all_images,
        metadata: {
          has_images: all_images.any?,
          thread_views: doc.css(".pairs--justified dd").text.gsub(/[^\d]/, "").to_i,
          reply_count: posts.size - 1,
          has_vba_code: has_vba,
          vba_code_blocks: vba_count,
          has_excel_table: has_excel_table,
          excel_tables: table_count,
          has_formulas: has_formulas,
          formula_count: formula_count,
          has_solution: solution_post.present?,
          is_accepted_solution: solution_post.present?,
          content_structure: {
            vba: has_vba,
            tables: has_excel_table,
            formulas: has_formulas,
            images: all_images.any?
          }
        }
      }

    rescue => e
      Rails.logger.error "Failed to fetch MrExcel thread #{thread_url}: #{e.message}"
      nil
    end
  end

  def extract_text_from_element(element)
    return "" unless element

    # Clone element to avoid modifying original
    elem = element.dup

    # Remove quotes to avoid duplication
    elem.css(".bbCodeBlock--quote").remove

    # Extract and preserve VBA code blocks
    vba_blocks = []
    elem.css(".bbCodeBlock").each do |block|
      if block.text.match?(/\b(Sub|Function|Dim|End Sub|End Function)\b/i)
        vba_code = block.css(".bbCodeCode, pre").text.strip
        vba_blocks << vba_code
        block.replace("\n\n[VBA CODE]\n```vba\n#{vba_code}\n```\n\n")
      end
    end

    # Extract and preserve Excel tables (xl2bb format)
    excel_tables = []
    elem.css('table.xl2bb, table[class*="xl2bb"]').each do |table|
      # Convert table to markdown
      markdown_table = convert_excel_table_to_markdown(table)
      excel_tables << markdown_table
      table.replace("\n\n[EXCEL TABLE]\n#{markdown_table}\n\n")
    end

    # Preserve inline code/formulas
    elem.css("code").each do |code|
      formula = code.text.strip
      if formula.start_with?("=")
        code.replace("`#{formula}`")
      end
    end

    # Replace other code blocks
    elem.css(".bbCodeBlock--code").each do |code|
      code_text = code.css(".bbCodeCode").text.strip
      code.replace("\n\n```\n#{code_text}\n```\n\n")
    end

    # Extract text content while preserving structure
    # First, get all text nodes (not just element.text which flattens everything)
    text_content = []

    # Walk through all nodes and extract text
    elem.traverse do |node|
      if node.text? && node.content.strip.length > 0
        text_content << node.content.strip
      elsif node.name == "br" || node.name == "p" || node.name == "div"
        text_content << "\n"
      end
    end

    # Join and clean up
    text = text_content.join(" ")
                      .gsub(/\s*\n\s*\n\s*/, "\n\n")  # Clean up multiple newlines
                      .gsub(/[ \t]+/, " ")             # Multiple spaces to single
                      .gsub(/\n\s+/, "\n")             # Remove spaces after newlines
                      .strip

    # Ensure we have actual content beyond just markers
    if text.match?(/\A(\[EXCEL TABLE\]|\[VBA CODE\]|\s|\n)*\z/)
      # If only markers, try simpler extraction
      text = elem.text.strip.gsub(/\s+/, " ")
    end

    text
  end

  def convert_excel_table_to_markdown(table_element)
    rows = table_element.css("tr")
    return "" if rows.empty?

    markdown_lines = []

    rows.each_with_index do |row, index|
      cells = row.css("td, th")
      cell_values = cells.map { |cell| cell.text.strip.gsub("|", '\\|') }
      markdown_lines << "| #{cell_values.join(' | ')} |"

      # Add header separator after first row
      if index == 0
        separator = "|" + (" --- |" * cells.length)
        markdown_lines << separator
      end
    end

    markdown_lines.join("\n")
  end
end
