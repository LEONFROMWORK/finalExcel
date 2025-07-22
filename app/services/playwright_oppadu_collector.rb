# frozen_string_literal: true

require "playwright"
require "set"

# Playwright-based Oppadu collector for Railway deployment
# Uses remote browser connection to Browserless service
class PlaywrightOppaduCollector
  def initialize(options = {})
    @options = {
      limit: 10,
      max_pages: 10,
      headless: true
    }.merge(options)

    @base_url = "https://www.oppadu.com"
    @community_url = "#{@base_url}/community/question/"

    # Remote browser endpoint (for Railway deployment)
    @browser_endpoint = ENV["BROWSER_PLAYWRIGHT_ENDPOINT"] || ENV["BROWSERLESS_URL"]

    Rails.logger.info "PlaywrightOppaduCollector initialized"
    Rails.logger.info "Browser endpoint: #{@browser_endpoint}" if @browser_endpoint
  end

  def collect_data(limit = nil)
    limit ||= @options[:limit]
    Rails.logger.info "Starting Playwright Oppadu collection (limit: #{limit})"

    begin
      if @browser_endpoint
        # Remote browser connection (for Railway)
        collect_with_remote_browser(limit)
      else
        # Local browser (for development)
        collect_with_local_browser(limit)
      end
    rescue => e
      Rails.logger.error "Playwright collection error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      {
        success: false,
        platform: "oppadu",
        results: [],
        error: "Playwright collection failed: #{e.message}"
      }
    end
  end

  private

  def collect_with_remote_browser(limit)
    Playwright.create(playwright_cli_executable_path: ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"] || "./node_modules/.bin/playwright") do |playwright|
      Rails.logger.info "Connecting to remote browser: #{@browser_endpoint}"

      browser = playwright.chromium.connect(@browser_endpoint)
      collect_with_browser(browser, limit)
    end
  end

  def collect_with_local_browser(limit)
    Playwright.create(playwright_cli_executable_path: "./node_modules/.bin/playwright") do |playwright|
      Rails.logger.info "Launching local browser"

      browser = playwright.chromium.launch(
        headless: @options[:headless],
        args: [ "--no-sandbox", "--disable-dev-shm-usage" ]
      )
      collect_with_browser(browser, limit)
    end
  end

  def collect_with_browser(browser, limit)
    results = []
    seen_post_ids = Set.new

    page = browser.new_page

    # Add stealth mode to avoid detection
    page.add_init_script(stealth_script)

    # Set viewport and user agent
    page.set_viewport_size(width: 1920, height: 1080)
    page.context.set_extra_http_headers({
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Accept-Language" => "ko-KR,ko;q=0.9,en;q=0.8"
    })

    page_num = 1

    while results.size < limit && page_num <= @options[:max_pages]
      url = page_num > 1 ? "#{@community_url}?pg=#{page_num}" : @community_url
      Rails.logger.info "Navigating to page #{page_num}: #{url}"

      begin
        page.goto(url, wait_until: "networkidle")

        # Wait for posts to load
        page.wait_for_selector(".post-list-modern", timeout: 10000)

        # Find all answered posts
        all_posts = page.locator(".post-item-modern").element_handles
        answered_posts = []

        all_posts.each do |post|
          # Check if has answer badge
          badge = post.query_selector(".answer-complete-badge")
          answered_posts << post if badge
        end

        Rails.logger.info "Found #{answered_posts.size} answered posts on page #{page_num}"

        # Process each answered post
        answered_posts.each do |post|
          break if results.size >= limit

          begin
            # Extract basic info
            link_elem = post.query_selector("a")
            next unless link_elem

            title = link_elem.text_content.strip
            href = link_elem.get_attribute("href")

            # Build full URL
            post_url = build_full_url(href)

            # Extract post ID
            post_id = extract_post_id(post_url)
            next if post_id.nil? || seen_post_ids.include?(post_id)

            seen_post_ids.add(post_id)

            # Collect detailed data
            Rails.logger.info "Collecting details for: #{title}"
            qa_data = collect_post_details(page, post_url, title)

            if qa_data && !has_base64_image?(qa_data)
              results << qa_data
              Rails.logger.info "Successfully collected: #{title}"
            end

          rescue => e
            Rails.logger.error "Error processing post: #{e.message}"
          end
        end

      rescue => e
        Rails.logger.error "Error on page #{page_num}: #{e.message}"
      end

      page_num += 1
    end

    browser.close

    # Save results
    save_status = save_results(results) if results.any?

    {
      success: true,
      platform: "oppadu",
      results: results,
      collection_method: "playwright",
      save_status: save_status,
      message: "Collected #{results.size} items using Playwright"
    }
  end

  def collect_post_details(page, url, title)
    # Navigate to post detail page
    page.goto(url, wait_until: "networkidle")

    # Wait for content to load
    page.wait_for_selector(".post-content", timeout: 10000)

    # Extract question
    question_elem = page.query_selector(".post-content")
    return nil unless question_elem
    question_content = question_elem.text_content.strip

    # Extract selected answer
    answer_elem = page.query_selector(".comment-wrapper.selected-answer .comment-body")
    return nil unless answer_elem

    answer_content = clean_text(answer_elem.text_content)
    return nil if answer_content.empty?

    # Extract images
    images = []
    has_base64 = false

    # Question images
    question_images = page.query_selector_all(".post-content img")
    question_images.each do |img|
      src = img.get_attribute("src")
      if src
        if src.start_with?("data:image")
          has_base64 = true
          Rails.logger.info "Found base64 image in question, skipping post"
          break
        end
        images << { url: src, context: "question" }
      end
    end

    return nil if has_base64

    # Answer images
    answer_images = page.query_selector_all(".comment-wrapper.selected-answer .comment-body img")
    answer_images.each do |img|
      src = img.get_attribute("src")
      if src
        if src.start_with?("data:image")
          has_base64 = true
          Rails.logger.info "Found base64 image in answer, skipping post"
          break
        end
        images << { url: src, context: "answer" }
      end
    end

    return nil if has_base64

    # Process images if any
    processed_answer = answer_content
    if images.any?
      begin
        processor = ThreeTierImageProcessor.new
        answer_images = images.select { |img| img[:context] == "answer" }

        processed_answer = processor.process_images_in_content(
          answer_content,
          answer_images,
          context_tags: [ "excel", "oppadu", "korean" ]
        )
      rescue => e
        Rails.logger.error "Image processing error: #{e.message}"
      end
    end

    {
      title: title,
      question: question_content,
      answer: processed_answer,
      link: url,
      tags: [ "excel", "korean" ],
      source: "oppadu",
      images: images,
      metadata: {
        collection_method: "playwright",
        has_images: images.any?,
        post_id: extract_post_id(url)
      }
    }
  rescue => e
    Rails.logger.error "Failed to collect details for #{url}: #{e.message}"
    nil
  end

  def build_full_url(href)
    return href if href.start_with?("http")

    if href.start_with?("?")
      @community_url + href
    elsif href.start_with?("/")
      @base_url + href
    else
      URI.join(@community_url, href).to_s
    end
  end

  def extract_post_id(url)
    match = url.match(/uid=(\d+)/)
    match ? match[1] : nil
  end

  def has_base64_image?(qa_data)
    qa_data[:images].any? { |img| img[:url]&.start_with?("data:image") }
  end

  def stealth_script
    # JavaScript to avoid automation detection
    <<~JS
      // Overwrite the `navigator.webdriver` property
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined
      });

      // Mock plugins to appear more like a real browser
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5]
      });

      // Mock languages
      Object.defineProperty(navigator, 'languages', {
        get: () => ['ko-KR', 'ko', 'en-US', 'en']
      });

      // Remove automation-related properties
      delete navigator.__proto__.webdriver;
    JS
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
end
