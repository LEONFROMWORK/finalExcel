# frozen_string_literal: true

# 간소화된 2-Tier AI 시스템
# Tier 1: 캐시된 패턴 + 정적 분석 (90% 해결)
# Tier 2: OpenRouter AI 호출 (10% 복잡한 케이스)
class SimplifiedTierEngine
  include Rails.application.routes.url_helpers

  CACHE_TTL = 24.hours
  CONFIDENCE_THRESHOLD = 0.8

  def initialize
    @static_analyzer = ExcelStaticAnalyzer.new
    @ai_solver = SmartExcelErrorSolver.new
  end

  def process(query, excel_file_path = nil, options = {})
    # 이미지가 포함된 경우 처리
    if options[:image_paths].present?
      return process_with_images(query, excel_file_path, options)
    end

    # 쿼리 정규화 및 핑거프린트 생성
    normalized_query = normalize_query(query)
    query_fingerprint = generate_fingerprint(normalized_query)

    # Tier 1: 캐시 확인
    cached_result = Rails.cache.fetch("tier1:#{query_fingerprint}", expires_in: CACHE_TTL) do
      find_best_pattern_match(normalized_query)
    end

    if cached_result && cached_result[:confidence] >= CONFIDENCE_THRESHOLD
      # 사용 기록 저장
      track_pattern_usage(cached_result[:pattern], true)

      return {
        tier: 1,
        solution: cached_result[:solution],
        confidence: cached_result[:confidence],
        pattern_id: cached_result[:pattern]&.id,
        cached: true
      }
    end

    # Tier 1: 정적 분석 시도
    if excel_file_path
      static_result = @static_analyzer.analyze_file(excel_file_path)

      if static_result[:success] && static_result[:error_found]
        solution = format_static_solution(static_result)

        # 성공적인 정적 분석 결과 캐싱
        Rails.cache.write("tier1:#{query_fingerprint}", {
          solution: solution,
          confidence: 0.85,
          pattern: nil
        }, expires_in: CACHE_TTL)

        return {
          tier: 1,
          solution: solution,
          confidence: 0.85,
          static_analysis: true
        }
      end
    end

    # Tier 2: AI 처리 (OpenRouter)
    ai_result = @ai_solver.solve_with_tier(
      error_description: query,
      excel_file_path: excel_file_path,
      tier: options[:user_tier] || :basic
    )

    if ai_result[:success]
      # AI 결과도 캐싱 (짧은 TTL)
      Rails.cache.write("tier2:#{query_fingerprint}", ai_result, expires_in: 1.hour)

      return {
        tier: 2,
        solution: ai_result[:solution],
        confidence: ai_result[:confidence] || 0.7,
        ai_model: ai_result[:model_used],
        credits_used: ai_result[:credits_used]
      }
    end

    # 실패 시 기본 응답
    {
      tier: 0,
      solution: "죄송합니다. 현재 이 문제에 대한 해결책을 찾을 수 없습니다. 더 구체적인 정보를 제공해 주시면 도움이 될 것 같습니다.",
      confidence: 0.0,
      error: ai_result[:error]
    }
  end

  private

  def process_with_images(query, excel_file_path, options)
    # 이미지 분석을 포함한 처리
    image_contexts = []

    # 각 이미지 분석
    options[:image_paths].each do |image_path|
      if File.exist?(image_path)
        context = analyze_image(image_path)
        image_contexts << context if context
      end
    end

    # 이미지 컨텍스트를 쿼리에 추가
    enhanced_query = build_enhanced_query(query, image_contexts)

    # Excel 파일과 이미지 정보를 함께 분석
    if excel_file_path && File.exist?(excel_file_path)
      excel_context = analyze_excel_with_images(excel_file_path, image_contexts)
      enhanced_query += "\n\nExcel 분석 결과: #{excel_context}" if excel_context
    end

    # Tier 2로 직접 전달 (이미지가 있는 경우 AI가 필요)
    ai_result = @ai_solver.solve_with_multimodal(
      error_description: enhanced_query,
      excel_file_path: excel_file_path,
      image_contexts: image_contexts,
      tier: options[:user_tier] || :pro  # 이미지 분석은 Pro tier 권장
    )

    if ai_result[:success]
      return {
        tier: 2,
        solution: ai_result[:solution],
        confidence: ai_result[:confidence] || 0.8,
        ai_model: ai_result[:model_used],
        credits_used: ai_result[:credits_used],
        multimodal: true,
        image_analysis: image_contexts.map { |ctx| ctx[:description] }
      }
    end

    # 실패 시 기본 응답
    {
      tier: 2,
      solution: "이미지와 Excel 파일을 분석했지만 명확한 해결책을 찾지 못했습니다. 이미지가 선명하고 오류 메시지가 잘 보이는지 확인해 주세요.",
      confidence: 0.0,
      error: ai_result[:error],
      multimodal: true
    }
  end

  def analyze_image(image_path)
    # 이미지 분석 (OCR + 구조 인식)
    {
      path: image_path,
      description: extract_image_content(image_path),
      detected_errors: detect_excel_errors_in_image(image_path),
      cell_references: extract_cell_references(image_path)
    }
  rescue => e
    Rails.logger.error "Image analysis failed: #{e.message}"
    nil
  end

  def extract_image_content(image_path)
    # TODO: 실제 OCR 구현 또는 AI Vision API 사용
    # 임시로 기본 설명 반환
    "Excel 스크린샷 이미지"
  end

  def detect_excel_errors_in_image(image_path)
    # TODO: 이미지에서 Excel 오류 감지
    # #REF!, #VALUE! 등의 텍스트 찾기
    []
  end

  def extract_cell_references(image_path)
    # TODO: 이미지에서 셀 참조 추출
    # A1, B2:C5 등의 패턴 찾기
    []
  end

  def analyze_excel_with_images(excel_file_path, image_contexts)
    # Excel 파일과 이미지 정보를 연관시켜 분석
    excel_data = @static_analyzer.analyze_file(excel_file_path)

    if excel_data[:success]
      # 이미지에서 발견된 셀 참조와 Excel 데이터 매칭
      matched_cells = match_cells_with_images(excel_data, image_contexts)

      if matched_cells.any?
        "이미지와 매칭된 셀: #{matched_cells.join(', ')}"
      else
        "Excel 파일 분석 완료"
      end
    end
  rescue => e
    Rails.logger.error "Excel-Image analysis failed: #{e.message}"
    nil
  end

  def match_cells_with_images(excel_data, image_contexts)
    # 이미지에서 추출한 셀 참조와 Excel 데이터 매칭
    matched = []

    image_contexts.each do |context|
      context[:cell_references].each do |cell_ref|
        # TODO: 실제 매칭 로직 구현
        matched << cell_ref
      end
    end

    matched.uniq
  end

  def build_enhanced_query(original_query, image_contexts)
    enhanced = original_query

    if image_contexts.any?
      enhanced += "\n\n이미지 분석 결과:"
      image_contexts.each_with_index do |context, idx|
        enhanced += "\n이미지 #{idx + 1}: #{context[:description]}"

        if context[:detected_errors].any?
          enhanced += "\n  발견된 오류: #{context[:detected_errors].join(', ')}"
        end

        if context[:cell_references].any?
          enhanced += "\n  참조된 셀: #{context[:cell_references].join(', ')}"
        end
      end
    end

    enhanced
  end

  def normalize_query(query)
    query.downcase
         .gsub(/\s+/, " ")
         .gsub(/[^\w\s가-힣#!@$%&*()_+=\-\/]/, "")
         .strip
  end

  def generate_fingerprint(normalized_query)
    Digest::SHA256.hexdigest(normalized_query)[0..16]
  end

  def find_best_pattern_match(query)
    # pgvector를 사용한 의미적 유사성 검색
    embedding = generate_embedding(query)

    patterns = ErrorPattern.approved
                          .nearest_neighbors(:embedding, embedding, distance: "cosine")
                          .limit(5)

    return nil if patterns.empty?

    # 가장 유사한 패턴 선택
    best_pattern = patterns.first
    similarity = calculate_similarity(query, best_pattern.question)

    if similarity > 0.7
      {
        pattern: best_pattern,
        solution: best_pattern.answer,
        confidence: [ similarity, best_pattern.confidence ].min
      }
    else
      nil
    end
  end

  def generate_embedding(text)
    # OpenAI 임베딩 서비스 사용
    service = KnowledgeBase::Services::EmbeddingService.new
    result = service.generate_embedding(text)

    result[:embedding] if result[:success]
  rescue => e
    Rails.logger.error "Embedding generation failed: #{e.message}"
    nil
  end

  def calculate_similarity(text1, text2)
    # 간단한 코사인 유사도 계산
    return 0.0 if text1.blank? || text2.blank?

    words1 = text1.downcase.split.to_set
    words2 = text2.downcase.split.to_set

    intersection = words1 & words2
    union = words1 | words2

    return 0.0 if union.empty?

    intersection.size.to_f / union.size
  end

  def track_pattern_usage(pattern, resolved)
    return unless pattern

    ErrorPatternUsage.create!(
      error_pattern: pattern,
      user: User.first, # TODO: 실제 사용자로 변경
      resolved: resolved,
      context: { tier: 1, cached: true }
    )

    # 사용 횟수 업데이트
    pattern.increment!(:usage_count)
  rescue => e
    Rails.logger.error "Failed to track pattern usage: #{e.message}"
  end

  def format_static_solution(static_result)
    solution = "정적 분석 결과:\n\n"

    if static_result[:errors].present?
      solution += "발견된 오류:\n"
      static_result[:errors].each do |error|
        solution += "• #{error[:type]}: #{error[:message]}\n"
        solution += "  위치: #{error[:location]}\n" if error[:location]
      end
    end

    if static_result[:suggestions].present?
      solution += "\n해결 방법:\n"
      static_result[:suggestions].each do |suggestion|
        solution += "• #{suggestion}\n"
      end
    end

    solution
  end
end
