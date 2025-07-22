# frozen_string_literal: true

require "open-uri"
require "nokogiri"
require "set"

##
# Simple Oppadu Collector without image processing
# Just collects Q&A data quickly
class OppaduSimpleCollector
  def initialize(options = {})
    @options = {
      limit: 10,
      max_pages: 5
    }.merge(options)

    @base_url = "https://www.oppadu.com"
    @community_url = "#{@base_url}/community/question/"
  end

  def collect_data
    results = []
    seen_post_ids = Set.new
    page = 1

    Rails.logger.info "Starting simple Oppadu collection (limit: #{@options[:limit]})"

    while results.size < @options[:limit] && page <= @options[:max_pages]
      begin
        # Build page URL
        page_url = page > 1 ? "#{@community_url}?board_id=&pg=#{page}" : @community_url
        Rails.logger.info "Fetching page #{page}: #{page_url}"

        # Fetch page
        html = URI.open(page_url,
          "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Accept-Language" => "ko-KR,ko;q=0.9"
        ).read

        doc = Nokogiri::HTML(html)

        # Find answered posts
        post_list = doc.css(".post-list-modern").first
        break unless post_list

        posts = post_list.css(".post-item-modern")
        Rails.logger.info "Found #{posts.size} posts on page #{page}"

        answered_count = 0
        posts.each do |post|
          break if results.size >= @options[:limit]

          # Check if answered
          has_answer = post.css(".answer-complete-badge").any?
          next unless has_answer

          answered_count += 1

          # Get link and title
          link_elem = post.css("a.post-title-modern").first || post.css("a").first
          next unless link_elem

          title = link_elem.text.strip
          href = link_elem["href"]

          # Build full URL
          post_url = if href.start_with?("?")
            @community_url + href
          elsif href.start_with?("/")
            @base_url + href
          elsif href.start_with?("http")
            href
          else
            URI.join(@community_url, href).to_s
          end

          # Extract post ID
          post_id = post_url[/uid=(\d+)/, 1]
          next if post_id.nil? || seen_post_ids.include?(post_id)

          seen_post_ids.add(post_id)

          # Fetch post details
          begin
            sleep(1) # Rate limit

            post_html = URI.open(post_url,
              "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
              "Accept-Language" => "ko-KR,ko;q=0.9"
            ).read

            post_doc = Nokogiri::HTML(post_html)

            # Extract question
            question_content = post_doc.css(".post-content").first&.text&.strip || ""

            # Extract answer
            answer_elem = post_doc.css(".comment-wrapper.selected-answer .comment-content").first
            answer_content = answer_elem&.text&.strip || ""

            # Fallback to first comment if no selected answer
            if answer_content.empty?
              first_comment = post_doc.css(".comment-wrapper .comment-content").first
              answer_content = first_comment&.text&.strip || ""
            end

            next if answer_content.empty?

            # Add to results
            results << {
              title: title,
              question: question_content,
              answer: answer_content,
              link: post_url,
              tags: extract_tags(title + " " + question_content),
              source: "oppadu",
              images: [], # No image processing
              metadata: {
                post_id: post_id,
                has_formulas: answer_content.include?("="),
                formula_count: answer_content.scan(/=[A-Z가-힣]+\(/).size,
                collection_method: "simple_nokogiri"
              }
            }

            Rails.logger.info "Collected: #{title}"

          rescue => e
            Rails.logger.error "Failed to fetch #{post_url}: #{e.message}"
          end
        end

        Rails.logger.info "Collected #{answered_count} answered posts from page #{page}"
        page += 1

      rescue => e
        Rails.logger.error "Error on page #{page}: #{e.message}"
        break
      end
    end

    {
      success: true,
      platform: "oppadu",
      results: results,
      collection_method: "simple_nokogiri",
      message: "Collected #{results.size} items from Oppadu (simple mode)"
    }

  rescue => e
    {
      success: false,
      platform: "oppadu",
      results: [],
      error: "Simple collection failed: #{e.message}"
    }
  end

  private

  def extract_tags(text)
    tags = []

    # Common Korean Excel terms
    korean_terms = {
      "함수" => "function",
      "수식" => "formula",
      "피벗" => "pivot",
      "차트" => "chart",
      "그래프" => "graph",
      "매크로" => "macro",
      "VBA" => "vba",
      "필터" => "filter",
      "정렬" => "sort",
      "조건부서식" => "conditional-formatting"
    }

    korean_terms.each do |korean, english|
      tags << english if text.include?(korean)
    end

    # Excel functions
    excel_functions = %w[VLOOKUP INDEX MATCH SUMIF COUNTIF IF IFERROR CONCATENATE TEXTJOIN]
    excel_functions.each do |func|
      tags << func.downcase if text.include?(func)
    end

    tags.uniq
  end
end
