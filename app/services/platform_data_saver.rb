# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'

##
# Platform Data Saver
# 플랫폼별 수집된 데이터를 일일 단위로 저장하고 중복을 제거
#
# Features:
# - 일일 단위 파일 관리 (같은 날짜면 누적)
# - 중복 데이터 제거 (post_id 또는 link 기준)
# - 3-tier 이미지 처리 결과 포함
# - 품질 지표 자동 계산
class PlatformDataSaver
  def initialize
    @export_dir = Rails.root.join('tmp', 'platform_datasets')
    FileUtils.mkdir_p(@export_dir)
    @logger = Rails.logger
  end

  ##
  # 플랫폼 데이터 저장 (일일 누적, 중복 제거)
  # 
  # @param platform [String] 플랫폼 이름
  # @param results [Array<Hash>] 수집된 결과들
  # @param metadata [Hash] 추가 메타데이터
  def save_platform_data(platform, results, metadata = {})
    return { success: false, error: 'No results to save' } if results.blank?
    
    # 오늘 날짜의 파일명
    date_str = Date.current.strftime('%Y%m%d')
    filename = "#{platform}_dataset_#{date_str}.json"
    filepath = @export_dir.join(filename)
    
    # 기존 데이터 로드 또는 새로 생성
    existing_data = load_existing_data(filepath, platform)
    
    # 중복 제거를 위한 기존 ID/링크 Set
    existing_ids = Set.new
    existing_links = Set.new
    
    existing_data[:items].each do |item|
      # Post ID 또는 링크로 중복 체크
      post_id = item.dig(:metadata, :post_id)
      existing_ids.add(post_id) if post_id
      existing_links.add(item[:link]) if item[:link]
    end
    
    # 새 항목 추가 (중복 제거)
    new_items = []
    duplicates = 0
    
    results.each do |result|
      # 중복 체크
      post_id = result.dig(:metadata, :post_id)
      link = result[:link]
      
      is_duplicate = false
      is_duplicate = true if post_id && existing_ids.include?(post_id)
      is_duplicate = true if link && existing_links.include?(link)
      
      if is_duplicate
        duplicates += 1
        @logger.info "Skipping duplicate item: #{result[:title]}"
        next
      end
      
      # 품질 지표 계산
      quality_indicators = calculate_quality_indicators(result)
      
      # 새 항목 생성
      new_item = {
        id: existing_data[:items].size + new_items.size + 1,
        title: result[:title],
        question: result[:question],
        answer: result[:answer],
        link: link,
        tags: result[:tags] || [],
        source: result[:source] || platform,
        metadata: result[:metadata] || {},
        images: result[:images] || [],
        quality_indicators: quality_indicators,
        collected_at: Time.current.iso8601
      }
      
      new_items << new_item
      
      # ID/링크 추가
      existing_ids.add(post_id) if post_id
      existing_links.add(link) if link
    end
    
    # 데이터 업데이트
    existing_data[:items].concat(new_items)
    existing_data[:total_count] = existing_data[:items].size
    existing_data[:last_updated] = Time.current.iso8601
    existing_data[:collection_stats][:total_collections] += 1
    existing_data[:collection_stats][:last_collection] = {
      timestamp: Time.current.iso8601,
      new_items: new_items.size,
      duplicates: duplicates,
      total_attempted: results.size
    }
    
    # 메타데이터 병합
    existing_data[:metadata].merge!(metadata) if metadata.any?
    
    # 파일 저장
    File.write(filepath, JSON.pretty_generate(existing_data))
    
    @logger.info "Saved #{new_items.size} new items to #{filepath} (#{duplicates} duplicates skipped)"
    
    {
      success: true,
      filepath: filepath,
      new_items: new_items.size,
      duplicates: duplicates,
      total_items: existing_data[:items].size,
      message: "Saved #{new_items.size} new items, skipped #{duplicates} duplicates. Total: #{existing_data[:items].size} items"
    }
  rescue => e
    @logger.error "Failed to save platform data: #{e.message}"
    { success: false, error: e.message }
  end

  ##
  # 모든 플랫폼의 오늘 데이터 요약
  def generate_daily_summary
    date_str = Date.current.strftime('%Y%m%d')
    platforms = %w[stackoverflow reddit mrexcel oppadu]
    
    summary = {
      date: Date.current.iso8601,
      platforms: {},
      totals: {
        items: 0,
        with_images: 0,
        with_vba: 0,
        with_tables: 0,
        with_formulas: 0
      }
    }
    
    platforms.each do |platform|
      filename = "#{platform}_dataset_#{date_str}.json"
      filepath = @export_dir.join(filename)
      
      if File.exist?(filepath)
        data = JSON.parse(File.read(filepath), symbolize_names: true)
        
        platform_stats = {
          total_items: data[:total_count],
          collections_today: data.dig(:collection_stats, :total_collections) || 0,
          last_collection: data.dig(:collection_stats, :last_collection, :timestamp),
          with_images: data[:items].count { |i| i.dig(:images)&.any? },
          with_vba: data[:items].count { |i| i.dig(:quality_indicators, :has_vba) },
          with_tables: data[:items].count { |i| i.dig(:quality_indicators, :has_table) },
          with_formulas: data[:items].count { |i| i.dig(:quality_indicators, :has_formula) },
          avg_answer_length: calculate_average(data[:items]) { |i| i.dig(:quality_indicators, :answer_length) || 0 }
        }
        
        summary[:platforms][platform] = platform_stats
        
        # Update totals
        summary[:totals][:items] += platform_stats[:total_items]
        summary[:totals][:with_images] += platform_stats[:with_images]
        summary[:totals][:with_vba] += platform_stats[:with_vba]
        summary[:totals][:with_tables] += platform_stats[:with_tables]
        summary[:totals][:with_formulas] += platform_stats[:with_formulas]
      else
        summary[:platforms][platform] = { status: 'no_data_today' }
      end
    end
    
    # Save summary
    summary_filepath = @export_dir.join("daily_summary_#{date_str}.json")
    File.write(summary_filepath, JSON.pretty_generate(summary))
    
    summary
  end

  private

  ##
  # 기존 데이터 로드 또는 새 구조 생성
  def load_existing_data(filepath, platform)
    if File.exist?(filepath)
      JSON.parse(File.read(filepath), symbolize_names: true)
    else
      {
        platform: platform,
        date: Date.current.iso8601,
        created_at: Time.current.iso8601,
        last_updated: Time.current.iso8601,
        total_count: 0,
        processing_type: '3-tier image processing enabled',
        collection_stats: {
          total_collections: 0,
          last_collection: nil
        },
        metadata: {},
        items: []
      }
    end
  end

  ##
  # 품질 지표 계산
  def calculate_quality_indicators(item)
    answer = item[:answer] || ''
    images = item[:images] || []
    
    {
      answer_length: answer.length,
      has_code: answer.include?('```'),
      has_formula: answer.match?(/`=[^`]+`/) || answer.match?(/^=/) || answer.match?(/\s=\w+\(/),
      has_vba: item[:metadata]&.dig('has_vba_code') || answer.match?(/\b(Sub|Function|Dim|End Sub|End Function)\b/i),
      has_table: item[:metadata]&.dig('has_excel_table') || answer.include?('|') && answer.include?('---'),
      has_images: images.any?,
      image_count: images.size,
      image_processing_tiers: images.map { |img| img[:processing_tier] }.compact.uniq,
      formula_count: item[:metadata]&.dig('formula_count') || answer.scan(/`=[^`]+`/).size,
      content_type: determine_content_type(item)
    }
  end

  ##
  # 컨텐츠 타입 결정
  def determine_content_type(item)
    answer = item[:answer] || ''
    
    if item[:metadata]&.dig('has_vba_code') || answer.match?(/\b(Sub|Function)\b/i)
      'vba_solution'
    elsif answer.match?(/`=[^`]+`/) || answer.match?(/^=/)
      'formula_solution'
    elsif item[:metadata]&.dig('has_excel_table') || (answer.include?('|') && answer.include?('---'))
      'table_data'
    elsif item[:images]&.any?
      'visual_explanation'
    else
      'text_explanation'
    end
  end

  ##
  # 평균 계산 헬퍼
  def calculate_average(items, &block)
    return 0 if items.empty?
    
    total = items.sum(&block)
    total.to_f / items.size
  end
end