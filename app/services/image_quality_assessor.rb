# frozen_string_literal: true

##
# Image Quality Assessment Service
# Based on industry best practices for determining processing quality
# and triggering fallbacks between processing tiers
#
# Quality metrics:
# - OCR confidence scores (character/word level)
# - Text length and word count thresholds
# - Image resolution and contrast checks
# - Content type detection (table, chart, text)
class ImageQualityAssessor
  # Industry-standard confidence thresholds
  CONFIDENCE_THRESHOLDS = {
    high: 0.90,      # >90% - Direct pass-through
    medium: 0.70,    # 70-90% - May need enhancement
    low: 0.50,       # 50-70% - Needs fallback
    minimum: 0.30    # <30% - Likely failed
  }.freeze

  # Content quality thresholds
  QUALITY_THRESHOLDS = {
    min_text_length: 10,        # Minimum characters for valid OCR
    min_word_count: 3,          # Minimum words for meaningful text
    min_table_cells: 4,         # Minimum cells for table detection
    optimal_dpi: 300,           # Optimal image resolution
    min_dpi: 150               # Minimum acceptable resolution
  }.freeze

  # Processing tier quality requirements
  TIER_REQUIREMENTS = {
    tier1: { min_confidence: 0.70, min_text_length: 20 },
    tier2: { min_confidence: 0.60, min_table_cells: 4 },
    tier3: { min_confidence: 0.00 } # AI can handle any input
  }.freeze

  def initialize(logger: Rails.logger)
    @logger = logger
  end

  ##
  # Assess OCR quality and determine if fallback is needed
  # @param ocr_result [Hash] OCR extraction results
  # @return [Hash] Assessment with quality score and recommendations
  def assess_ocr_quality(ocr_result)
    return failed_assessment('No OCR result') if ocr_result.nil?

    text_length = ocr_result[:text_length] || 0
    word_count = ocr_result[:word_count] || 0
    confidence = ocr_result[:confidence] || 0.0

    # Calculate composite quality score
    quality_score = calculate_ocr_quality_score(text_length, word_count, confidence)
    
    assessment = {
      quality_score: quality_score,
      confidence_level: determine_confidence_level(quality_score),
      is_acceptable: quality_score >= CONFIDENCE_THRESHOLDS[:medium],
      needs_fallback: quality_score < CONFIDENCE_THRESHOLDS[:medium],
      metrics: {
        text_length: text_length,
        word_count: word_count,
        confidence: confidence
      }
    }

    # Add specific recommendations
    if assessment[:needs_fallback]
      assessment[:recommendations] = generate_ocr_recommendations(ocr_result)
    end

    @logger.info "OCR quality assessment: score=#{quality_score.round(2)}, " \
                 "acceptable=#{assessment[:is_acceptable]}"

    assessment
  end

  ##
  # Assess table detection quality
  # @param table_result [Hash] Table detection results
  # @return [Hash] Assessment with quality metrics
  def assess_table_quality(table_result)
    return failed_assessment('No table result') if table_result.nil?

    tables_found = table_result[:tables_found] || 0
    has_content = table_result[:markdown_content].present?
    
    # Simple table quality score
    quality_score = if tables_found > 0 && has_content
                     0.9
                   elsif tables_found > 0
                     0.6
                   else
                     0.0
                   end

    {
      quality_score: quality_score,
      is_acceptable: tables_found > 0 && has_content,
      needs_fallback: quality_score < 0.6,
      metrics: {
        tables_found: tables_found,
        has_markdown: has_content
      }
    }
  end

  ##
  # Determine if AI enhancement should be attempted
  # Based on content complexity and previous tier results
  def should_attempt_ai_enhancement?(ocr_assessment, table_assessment, context_tags)
    # Always attempt if both previous tiers failed
    if !ocr_assessment[:is_acceptable] && !table_assessment[:is_acceptable]
      @logger.info "AI enhancement recommended: Both OCR and table detection failed"
      return true
    end

    # Check for complex content indicators
    complex_content_indicators = [
      'chart', 'graph', 'diagram', 'plot', 'visualization',
      'formula', 'equation', 'complex', 'pivot'
    ]
    
    has_complex_content = context_tags.any? do |tag|
      complex_content_indicators.any? { |indicator| tag.downcase.include?(indicator) }
    end

    if has_complex_content
      @logger.info "AI enhancement recommended: Complex content detected"
      return true
    end

    # Check if current results are borderline
    avg_quality = (ocr_assessment[:quality_score] + table_assessment[:quality_score]) / 2.0
    if avg_quality < CONFIDENCE_THRESHOLDS[:medium]
      @logger.info "AI enhancement recommended: Average quality #{avg_quality.round(2)} below threshold"
      return true
    end

    false
  end

  ##
  # Assess overall processing result and determine final quality
  # @param processing_result [Hash] Complete processing result from any tier
  # @return [Hash] Final quality assessment
  def assess_final_quality(processing_result)
    return failed_assessment('No processing result') if processing_result.nil?

    content = processing_result[:extracted_content] || ''
    content_type = processing_result[:extracted_content_type]
    processing_tier = processing_result[:processing_tier]

    # Calculate final quality based on tier and content
    quality_score = calculate_final_quality_score(content, content_type, processing_tier)

    {
      quality_score: quality_score,
      confidence_level: determine_confidence_level(quality_score),
      is_high_quality: quality_score >= CONFIDENCE_THRESHOLDS[:high],
      is_acceptable: quality_score >= CONFIDENCE_THRESHOLDS[:medium],
      needs_human_review: quality_score < CONFIDENCE_THRESHOLDS[:low],
      processing_tier: processing_tier,
      content_summary: {
        type: content_type,
        length: content.length,
        has_meaningful_content: content.length > QUALITY_THRESHOLDS[:min_text_length]
      }
    }
  end

  private

  def calculate_ocr_quality_score(text_length, word_count, confidence)
    # Weighted scoring based on multiple factors
    length_score = [text_length.to_f / 100, 1.0].min * 0.3
    word_score = [word_count.to_f / 20, 1.0].min * 0.3
    confidence_score = confidence * 0.4

    length_score + word_score + confidence_score
  end

  def calculate_final_quality_score(content, content_type, processing_tier)
    base_score = case processing_tier
                 when /Tier 3/i then 0.9  # AI processing is highly reliable
                 when /Tier 2/i then 0.7  # Table detection is good
                 when /Tier 1/i then 0.5  # Basic OCR
                 else 0.3                 # Fallback/placeholder
                 end

    # Adjust based on content quality
    content_multiplier = case content_type
                        when 'markdown_table' then 1.1
                        when 'chart_description' then 1.2
                        when 'enhanced_text' then 1.15
                        when 'plain_text' then 1.0
                        else 0.8
                        end

    # Penalize very short content
    length_penalty = content.length < 20 ? 0.8 : 1.0

    [base_score * content_multiplier * length_penalty, 1.0].min
  end

  def determine_confidence_level(score)
    case score
    when 0.9..1.0 then :high
    when 0.7...0.9 then :medium
    when 0.5...0.7 then :low
    else :very_low
    end
  end

  def generate_ocr_recommendations(ocr_result)
    recommendations = []
    
    if ocr_result[:text_length] < QUALITY_THRESHOLDS[:min_text_length]
      recommendations << "Text too short, try image preprocessing"
    end
    
    if ocr_result[:word_count] < QUALITY_THRESHOLDS[:min_word_count]
      recommendations << "Few words detected, check image quality"
    end
    
    if ocr_result[:confidence] < CONFIDENCE_THRESHOLDS[:low]
      recommendations << "Low OCR confidence, use AI enhancement"
    end
    
    recommendations
  end

  def failed_assessment(reason)
    {
      quality_score: 0.0,
      confidence_level: :failed,
      is_acceptable: false,
      needs_fallback: true,
      error: reason
    }
  end
end