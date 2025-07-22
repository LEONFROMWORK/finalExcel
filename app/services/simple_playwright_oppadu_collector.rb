# frozen_string_literal: true

require "playwright"
require "set"

# Simple Playwright-based Oppadu collector
class SimplePlaywrightOppaduCollector
  def initialize(options = {})
    @options = {
      limit: 10,
      max_pages: 5,
      headless: true
    }.merge(options)

    @base_url = "https://www.oppadu.com"
    @community_url = "#{@base_url}/community/question/"
  end

  def collect_data(limit = nil)
    limit ||= @options[:limit]
    results = []

    Rails.logger.info "Starting Simple Playwright Oppadu collection (limit: #{limit})"

    begin
      Playwright.create(playwright_cli_executable_path: "./node_modules/.bin/playwright") do |playwright|
        playwright.chromium.launch(headless: @options[:headless]) do |browser|
          page = browser.new_page

          # Set user agent
          page.context.set_extra_http_headers({
            "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept-Language" => "ko-KR,ko;q=0.9,en;q=0.8"
          })

          seen_urls = Set.new
          page_num = 1

          while results.size < limit && page_num <= @options[:max_pages]
            url = page_num > 1 ? "#{@community_url}?pg=#{page_num}" : @community_url

            Rails.logger.info "Navigating to page #{page_num}: #{url}"
            page.goto(url)

            # Wait for posts to load
            page.wait_for_selector(".post-item-modern")

            # Get all posts
            posts = page.query_selector_all(".post-item-modern")
            Rails.logger.info "Found #{posts.size} posts on page #{page_num}"

            # Process each post
            posts.each do |post|
              break if results.size >= limit

              # Check for answer badge
              badge = post.query_selector(".answer-complete-badge")
              next unless badge

              # Get link
              link = post.query_selector("a")
              next unless link

              href = link.get_attribute("href")
              post_url = build_full_url(href)

              next if seen_urls.include?(post_url)
              seen_urls.add(post_url)

              title = link.text_content.strip
              Rails.logger.info "Processing: #{title}"

              # Navigate to detail page
              detail = collect_post_detail(browser, post_url, title)
              if detail
                results << detail
                Rails.logger.info "Collected: #{title}"
              end

              # Rate limit
              sleep(1)
            end

            page_num += 1
          end
        end
      end

      # Save results
      save_status = save_results(results) if results.any?

      {
        success: true,
        platform: "oppadu",
        results: results,
        collection_method: "simple_playwright",
        save_status: save_status,
        message: "Collected #{results.size} items using Simple Playwright"
      }

    rescue => e
      Rails.logger.error "Simple Playwright error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      {
        success: false,
        platform: "oppadu",
        results: [],
        error: "Simple Playwright failed: #{e.message}"
      }
    end
  end

  private

  def collect_post_detail(browser, url, title)
    detail_page = browser.new_page

    begin
      detail_page.goto(url)
      detail_page.wait_for_selector(".post-content")

      # Get question
      question_elem = detail_page.query_selector(".post-content")
      return nil unless question_elem
      question = question_elem.text_content.strip

      # Get answer
      answer_elem = detail_page.query_selector(".comment-wrapper.selected-answer .comment-body")
      return nil unless answer_elem
      answer = clean_text(answer_elem.text_content)

      # Get images from question and answer only (not header/footer)
      images = []
      has_base64 = false

      # Question images
      question_images = detail_page.query_selector_all(".post-content img")
      question_images.each do |img|
        src = img.get_attribute("src")
        if src
          # Skip logo images
          next if src.include?("logo") || src.include?(".svg")

          if src.start_with?("data:image")
            has_base64 = true
            Rails.logger.info "Skipping post with base64 image in question"
            break
          end
          images << { url: src, context: "question" }
        end
      end

      return nil if has_base64

      # Answer images
      answer_images = detail_page.query_selector_all(".comment-wrapper.selected-answer .comment-body img")
      answer_images.each do |img|
        src = img.get_attribute("src")
        if src
          # Skip logo images
          next if src.include?("logo") || src.include?(".svg")

          if src.start_with?("data:image")
            has_base64 = true
            Rails.logger.info "Skipping post with base64 image in answer"
            break
          end
          images << { url: src, context: "answer" }
        end
      end

      return nil if has_base64

      # Process images
      processed_answer = answer
      if images.any?
        begin
          processor = ThreeTierImageProcessor.new
          processed_answer = processor.process_images_in_content(
            answer,
            images,
            context_tags: [ "excel", "oppadu", "korean" ]
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
        tags: [ "excel", "korean" ],
        source: "oppadu",
        images: images,
        metadata: {
          collection_method: "simple_playwright",
          has_images: images.any?
        }
      }

    rescue => e
      Rails.logger.error "Failed to collect detail: #{e.message}"
      nil
    ensure
      detail_page.close
    end
  end

  def build_full_url(href)
    return href if href.start_with?("http")
    return @community_url + href if href.start_with?("?")
    return @base_url + href if href.start_with?("/")
    @community_url + href
  end

  def clean_text(text)
    return "" if text.nil?

    # Remove excessive whitespace and normalize
    text.strip
        .gsub(/\s+/, " ")           # Replace multiple spaces with single space
        .gsub(/\n\s*\n/, "\n\n")    # Replace multiple newlines with double newline
        .gsub(/&nbsp;/, " ")        # Replace HTML non-breaking spaces
        .gsub(/&lt;/, "<")          # Replace HTML entities
        .gsub(/&gt;/, ">")
        .gsub(/&amp;/, "&")
        .gsub(/&quot;/, '"')
        .gsub(/&#39;/, "'")
        .strip
  end

  def save_results(results)
    date_str = Date.current.strftime("%Y%m%d")
    export_dir = Rails.root.join("tmp", "platform_datasets")
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
    existing_ids = Set.new(existing_data.map { |item| item["link"] })
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
