# frozen_string_literal: true

require "base64"
require "tempfile"
require "open-uri"

# Enhanced platform data collector with image analysis capabilities
class EnhancedPlatformCollector < PlatformDataCollector
  def initialize(platform, options = {})
    super
    @openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  end

  def collect_with_images(limit = 10)
    result = collect_data(limit)

    return result unless result[:success] && result[:results].present?

    # Process each item for images
    enhanced_results = result[:results].map do |item|
      enhance_item_with_images(item)
    end

    result[:results] = enhanced_results
    result[:enhanced] = true
    result
  end

  private

  def enhance_item_with_images(item)
    # Check if item contains images
    images = extract_images_from_content(item)

    return item if images.empty?

    # Analyze each image
    image_analyses = images.map do |image_url|
      analyze_image_content(image_url)
    end

    # Merge image analysis into item
    item[:image_analyses] = image_analyses
    item[:has_images] = true

    # Enhanced answer with image context
    if item[:answer].present? && image_analyses.any?
      item[:enhanced_answer] = enhance_answer_with_images(item[:answer], image_analyses)
    end

    item
  end

  def extract_images_from_content(item)
    content = "#{item[:question]} #{item[:answer]}"
    image_urls = []

    # Extract image URLs from HTML content
    if content.include?("<img")
      doc = Nokogiri::HTML(content)
      doc.css("img").each do |img|
        src = img["src"]
        image_urls << src if src.present?
      end
    end

    # Extract markdown image links
    markdown_images = content.scan(/!\[.*?\]\((.*?)\)/).flatten
    image_urls.concat(markdown_images)

    # Extract direct image links
    direct_images = content.scan(/https?:\/\/[^\s]+\.(?:jpg|jpeg|png|gif|webp)/i)
    image_urls.concat(direct_images)

    image_urls.uniq
  end

  def analyze_image_content(image_url)
    return nil unless @openrouter_api_key

    begin
      # Download image
      image_data = download_image_data(image_url)
      return nil unless image_data

      # Use OpenRouter API with Claude 3 Sonnet for vision
      uri = URI("https://openrouter.ai/api/v1/chat/completions")

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@openrouter_api_key}"
      request["Content-Type"] = "application/json"
      request["HTTP-Referer"] = ENV["APP_URL"] || "http://localhost:3000"
      request["X-Title"] = "Excel Unified - Image Analysis"

      prompt = <<~PROMPT
        이 이미지를 분석해주세요. Excel 스프레드시트나 관련 내용이 있다면:
        1. 어떤 Excel 오류가 표시되어 있는지
        2. 사용된 수식이나 함수
        3. 참조된 셀 범위
        4. 데이터 구조나 문제점

        Excel과 관련 없다면 간단히 이미지 내용을 설명해주세요.
      PROMPT

      request.body = {
        model: "anthropic/claude-3-sonnet",
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: prompt },
              {
                type: "image_url",
                image_url: {
                  url: "data:#{image_data[:content_type]};base64,#{image_data[:base64]}"
                }
              }
            ]
          }
        ],
        max_tokens: 500
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == "200"
        data = JSON.parse(response.body)
        content = data["choices"][0]["message"]["content"] rescue nil

        {
          url: image_url,
          content: content || "",
          excel_errors: extract_excel_errors(content),
          cell_references: extract_cell_references(content),
          contains_excel_data: content&.match?(/excel|spreadsheet|수식|함수/i) || false
        }
      else
        Rails.logger.error "OpenRouter API error: #{response.code}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to analyze image #{image_url}: #{e.message}"
      nil
    end
  end

  def download_image_data(url)
    uri = URI(url)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ExcelUnified/1.0"
      http.request(request)
    end

    if response.code == "200"
      {
        data: response.body,
        base64: Base64.strict_encode64(response.body),
        content_type: response["Content-Type"] || "image/jpeg"
      }
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to download image #{url}: #{e.message}"
    nil
  end

  def extract_excel_errors(text)
    return [] unless text
    text.scan(/#[A-Z]+[!?]?/).uniq
  end

  def extract_cell_references(text)
    return [] unless text
    text.scan(/[A-Z]+\d+(?::[A-Z]+\d+)?/).uniq
  end

  def enhance_answer_with_images(original_answer, image_analyses)
    excel_images = image_analyses.select { |img| img[:contains_excel_data] }

    return original_answer if excel_images.empty?

    enhanced = original_answer + "\n\n### 📊 이미지 분석 결과:\n"

    excel_images.each_with_index do |img, idx|
      enhanced += "\n**이미지 #{idx + 1}:**\n"

      if img[:excel_errors].present?
        enhanced += "- 발견된 Excel 오류: #{img[:excel_errors].join(', ')}\n"
      end

      if img[:cell_references].present?
        enhanced += "- 참조된 셀: #{img[:cell_references].join(', ')}\n"
      end

      if img[:content].present?
        enhanced += "- 분석 내용: #{img[:content][0..200]}...\n"
      end
    end

    enhanced
  end
end
