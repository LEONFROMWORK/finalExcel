# frozen_string_literal: true

# Enhanced image content processor with 3-tier processing capability
# Integrates with ThreeTierImageProcessor for advanced image analysis
class ImageContentProcessor
  class << self
    # Main method - enhanced with 3-tier processing
    def process_images_in_content(content, images, use_advanced_processing: false, context_tags: [])
      return content if images.blank?

      processed_content = content.dup

      # If advanced processing is enabled, use 3-tier processor
      if use_advanced_processing
        image_descriptions = process_images_with_3tier(images, context_tags)
      else
        # Use basic processing (legacy behavior)
        image_descriptions = []
        images.each_with_index do |image, index|
          desc = build_image_description(image, index + 1)
          image_descriptions << desc if desc.present?
        end
      end

      if image_descriptions.any?
        processed_content += "\n\n[이미지 설명]\n#{image_descriptions.join("\n")}"
      end

      processed_content
    end

    # Enhanced image processing using 3-tier system
    def process_images_with_3tier(images, context_tags = [])
      processor = ThreeTierImageProcessor.new
      image_descriptions = []

      images.each_with_index do |image, index|
        next unless image[:url].present?

        begin
          # Process image with 3-tier system
          if image[:url].start_with?("data:image")
            # Handle base64 images
            result = processor.process_base64_image(image[:url], context_tags: context_tags)
          else
            # Handle external URLs
            result = processor.process_image_url(image[:url], context_tags: context_tags)
          end

          if result[:success] && result[:extracted_content].present?
            description = format_3tier_result(result, index + 1)
            image_descriptions << description if description.present?
          else
            # Fallback to basic description
            desc = build_image_description(image, index + 1)
            image_descriptions << desc if desc.present?
          end

        rescue => e
          Rails.logger.error "3-tier processing failed for image #{index + 1}: #{e.message}"
          # Fallback to basic description
          desc = build_image_description(image, index + 1)
          image_descriptions << desc if desc.present?
        end
      end

      image_descriptions
    end

    # Format 3-tier processing result into readable description
    def format_3tier_result(result, index)
      tier = result[:processing_tier]
      content_type = result[:extracted_content_type]
      content = result[:extracted_content]

      case content_type
      when "markdown_table"
        "이미지 #{index} (#{tier}): Excel 테이블\n#{content}"
      when "chart_description"
        "이미지 #{index} (#{tier}): #{content}"
      when "enhanced_text"
        "이미지 #{index} (#{tier}): #{content}"
      when "plain_text"
        "이미지 #{index} (#{tier}): #{content}"
      else
        "이미지 #{index} (#{tier}): 처리된 내용이 없습니다"
      end
    end

    def extract_images_from_html(html_content, base_url = nil)
      return [] unless html_content.present?

      images = []
      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)

      doc.css("img").each_with_index do |img, index|
        src = img["src"] || img["data-src"] || img["data-original-src"]
        next unless src.present?

        alt = img["alt"] || img["title"] || ""

        # 이미지 타입 결정
        image_info = if src.start_with?("data:image")
          {
            url: src,
            alt: alt,
            type: "base64",
            description: extract_base64_description(src, alt, img)
          }
        else
          full_url = normalize_image_url(src, base_url)
          {
            url: full_url,
            alt: alt,
            type: "external",
            description: extract_image_context(img, alt)
          }
        end

        images << image_info
      end

      images
    end

    private

    def build_image_description(image, index)
      case image[:type]
      when "base64"
        "이미지 #{index}: #{image[:description] || '엑셀 스크린샷'}"
      when "external"
        desc = image[:description] || image[:alt] || "관련 이미지"
        "이미지 #{index}: #{desc}"
      else
        nil
      end
    end

    def extract_base64_description(data_url, alt, img_element)
      # Base64 이미지 타입 확인
      if data_url.include?("image/png")
        type_desc = "PNG 스크린샷"
      elsif data_url.include?("image/jpeg") || data_url.include?("image/jpg")
        type_desc = "JPEG 이미지"
      else
        type_desc = "이미지"
      end

      # 테이블 내 이미지인지 확인
      if img_element.ancestors("table").any?
        type_desc += " (테이블 내)"
      end

      # alt 텍스트가 있으면 추가
      if alt.present?
        "#{alt} - #{type_desc}"
      else
        type_desc
      end
    end

    def extract_image_context(img_element, alt)
      context_parts = []

      # Alt 텍스트 우선
      context_parts << alt if alt.present?

      # 이미지 주변 텍스트 수집
      parent = img_element.parent
      if parent
        # 이전 텍스트 노드
        prev_text = extract_nearby_text(parent.previous_sibling)
        context_parts << prev_text if prev_text.present?

        # 다음 텍스트 노드
        next_text = extract_nearby_text(parent.next_sibling)
        context_parts << next_text if next_text.present?
      end

      # 테이블 컨텍스트
      if img_element.ancestors("table").any?
        context_parts << "테이블 데이터"
      end

      # figure/figcaption 처리
      figure = img_element.ancestors("figure").first
      if figure
        caption = figure.css("figcaption").first
        context_parts << caption.text.strip if caption
      end

      context_parts.compact.uniq.join(" - ").presence || "엑셀 관련 이미지"
    end

    def extract_nearby_text(node)
      return nil unless node

      text = node.text.strip
      return nil if text.blank?

      # 너무 긴 텍스트는 잘라냄
      text.length > 100 ? text[0..97] + "..." : text
    end

    def normalize_image_url(src, base_url)
      return src if src.start_with?("http://", "https://")
      return src unless base_url

      # 상대 경로를 절대 경로로 변환
      begin
        URI.join(base_url, src).to_s
      rescue URI::InvalidURIError
        src
      end
    end
  end
end
