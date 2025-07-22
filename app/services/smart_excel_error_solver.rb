# frozen_string_literal: true

# Excel 오류를 Tier 방식으로 해결하는 스마트 솔버
# Phase 1: 정적 분석 (무료)
# Phase 2: AI 텍스트 솔루션 (저비용)
# Phase 3: Code Interpreter (고비용)
class SmartExcelErrorSolver
  attr_reader :excel_file, :error_context, :ai_tier_service

  def initialize(excel_file = nil, error_context = {})
    @excel_file = excel_file
    @error_context = error_context
    @ai_tier_service = AiTierService.new
  end

  def call
    # 1단계: 정적 분석으로 해결 시도
    static_result = perform_static_analysis

    if static_result[:has_solution]
      return {
        success: true,
        solution: static_result[:solution],
        type: "static_analysis",
        tier: "free",
        cost: 0,
        confidence: static_result[:confidence]
      }
    end

    # 2단계: AI 텍스트 솔루션 (Basic/Pro Tier)
    ai_result = perform_ai_analysis(static_result[:context])

    if ai_result[:sufficient]
      return {
        success: true,
        solution: ai_result[:solution],
        type: "ai_guidance",
        tier: ai_result[:tier],
        cost: ai_result[:cost],
        confidence: ai_result[:confidence]
      }
    end

    # 3단계: Code Interpreter 필요 여부 판단
    if requires_code_execution?(ai_result[:analysis])
      return {
        success: true,
        requires_escalation: true,
        type: "code_execution_required",
        tier: "enterprise",
        message: "고급 분석이 필요합니다. 실행하시겠습니까?",
        estimated_cost: calculate_execution_cost,
        capabilities: available_code_execution_features
      }
    end

    {
      success: false,
      error: "해결책을 찾을 수 없습니다",
      attempted_solutions: [ static_result, ai_result ]
    }
  end

  # SimplifiedTierEngine에서 호출하는 메서드
  def solve_with_tier(error_description:, excel_file_path: nil, tier: :basic)
    # 문자열 설명만으로 해결 시도
    ai_service = UnifiedAiService.new(tier)

    response = ai_service.generate_text(
      prompt: build_error_solving_prompt(error_description),
      max_tokens: tier == :basic ? 1000 : 2000
    )

    if response[:success]
      {
        success: true,
        solution: response[:content],
        confidence: 0.7,
        model_used: response[:model],
        credits_used: response[:credits_used] || 0
      }
    else
      {
        success: false,
        error: response[:error]
      }
    end
  end

  def solve_with_multimodal(error_description:, excel_file_path: nil, image_contexts: [], tier: :pro)
    # 이미지를 포함한 멀티모달 분석
    ai_service = UnifiedAiService.new(tier)

    # 프롬프트 구성
    prompt = build_multimodal_prompt(error_description, image_contexts)

    # Vision 가능한 모델 사용 (OpenRouter의 GPT-4V 또는 Claude)
    response = ai_service.analyze_with_vision(
      prompt: prompt,
      images: image_contexts.map { |ctx| ctx[:path] },
      excel_context: excel_file_path ? extract_excel_context(excel_file_path) : nil
    )

    if response[:success]
      {
        success: true,
        solution: response[:content],
        confidence: 0.85,  # 이미지 분석은 더 높은 신뢰도
        model_used: response[:model],
        credits_used: response[:credits_used] || 0,
        vision_analysis: response[:vision_details]
      }
    else
      {
        success: false,
        error: response[:error]
      }
    end
  end

  private

  def build_error_solving_prompt(error_description)
    <<~PROMPT
      Excel 오류 해결 전문가로서 다음 문제를 해결해 주세요:

      문제 설명: #{error_description}

      다음 형식으로 답변해 주세요:
      1. 오류 원인 분석
      2. 구체적인 해결 방법 (단계별)
      3. 예시 수식이나 작업 방법
      4. 추가 권장사항

      한국어로 명확하고 실용적인 답변을 제공해 주세요.
    PROMPT
  end

  def build_multimodal_prompt(error_description, image_contexts)
    prompt = <<~PROMPT
      Excel 오류 해결 전문가로서 이미지와 설명을 분석하여 문제를 해결해 주세요:

      문제 설명: #{error_description}

      첨부된 이미지 정보:
    PROMPT

    image_contexts.each_with_index do |context, idx|
      prompt += "\n이미지 #{idx + 1}: #{context[:description]}"
      if context[:detected_errors].any?
        prompt += "\n  - 감지된 오류: #{context[:detected_errors].join(', ')}"
      end
    end

    prompt += <<~PROMPT


      이미지를 자세히 분석하여:
      1. 화면에 표시된 정확한 오류 메시지나 문제 상황을 파악
      2. 셀 참조, 수식, 데이터 구조 확인
      3. 구체적이고 실행 가능한 해결 방법 제시
      4. 스크린샷의 상황에 맞는 정확한 수식이나 작업 방법 제공

      한국어로 상세하고 실용적인 답변을 제공해 주세요.
    PROMPT

    prompt
  end

  def extract_excel_context(excel_file_path)
    # Excel 파일에서 관련 컨텍스트 추출
    return nil unless File.exist?(excel_file_path)

    analyzer = ExcelStaticAnalyzer.new
    result = analyzer.analyze_file(excel_file_path)

    if result[:success]
      {
        sheets: result[:sheets] || [],
        errors: result[:errors] || [],
        formulas: result[:formulas] || []
      }
    else
      nil
    end
  rescue => e
    Rails.logger.error "Excel context extraction failed: #{e.message}"
    nil
  end

  def perform_static_analysis
    analyzer = ExcelStaticAnalyzer.new(@excel_file)
    errors = analyzer.detect_errors

    solutions = {}
    has_solution = false

    errors.each do |error|
      solution = find_static_solution(error)
      if solution
        solutions[error[:type]] = solution
        has_solution = true
      end
    end

    {
      has_solution: has_solution,
      solution: solutions,
      context: {
        errors: errors,
        file_info: @excel_file.analysis_result
      },
      confidence: calculate_static_confidence(solutions, errors)
    }
  end

  def find_static_solution(error)
    case error[:type]
    when "#REF!"
      {
        description: "참조 오류: 삭제된 셀이나 시트를 참조하고 있습니다",
        steps: [
          "오류 위치: #{error[:location]}",
          "수식에서 참조하는 셀이나 시트가 존재하는지 확인하세요",
          "삭제된 행/열을 복구하거나 수식을 수정하세요"
        ],
        auto_fix: can_auto_fix_ref_error?(error)
      }

    when "#VALUE!"
      {
        description: "값 오류: 잘못된 데이터 타입입니다",
        steps: [
          "오류 위치: #{error[:location]}",
          "숫자가 필요한 곳에 텍스트가 있는지 확인하세요",
          "날짜 형식이 올바른지 확인하세요"
        ],
        auto_fix: suggest_value_fix(error)
      }

    when "#DIV/0!"
      {
        description: "0으로 나누기 오류",
        steps: [
          "오류 위치: #{error[:location]}",
          "분모가 0이 되지 않도록 IF문으로 보호하세요",
          "예: =IF(B1=0, \"\", A1/B1)"
        ],
        auto_fix: true
      }

    when "circular_reference"
      {
        description: "순환 참조 오류",
        steps: [
          "순환 참조 체인: #{error[:chain].join(' → ')}",
          "수식이 자기 자신을 참조하지 않도록 수정하세요"
        ],
        auto_fix: false
      }

    when "data_type_mismatch"
      {
        description: "데이터 타입 불일치",
        steps: [
          "열 #{error[:column]}: #{error[:expected_type]} 예상, #{error[:found_types].join(', ')} 발견",
          "데이터를 일관된 형식으로 변환하세요"
        ],
        auto_fix: can_auto_convert_types?(error)
      }
    else
      nil
    end
  end

  def perform_ai_analysis(static_context)
    # 사용자의 AI Tier 확인
    user = @excel_file.user
    tier_info = @ai_tier_service.get_user_tier_info(user)

    # Tier에 따른 AI 분석
    case tier_info[:tier]
    when :basic
      basic_ai_analysis(static_context, tier_info)
    when :pro
      pro_ai_analysis(static_context, tier_info)
    when :enterprise
      enterprise_ai_analysis(static_context, tier_info)
    else
      { sufficient: false, tier: "none", cost: 0 }
    end
  end

  def basic_ai_analysis(context, tier_info)
    # Basic Tier: 간단한 텍스트 기반 해결책
    bridge = ExcelLLMBridgeService.new(@excel_file)
    problem_context = bridge.create_problem_context(
      describe_errors(context[:errors]),
      max_tokens: 2000  # Basic은 토큰 제한
    )

    ai_service = UnifiedAiService.new(tier_info[:tier])
    response = ai_service.analyze_excel(
      @excel_file,
      problem_context[:problem],
      problem_context
    )

    if response.success?
      solution = bridge.parse_llm_solution(response.data[:content])

      {
        sufficient: is_solution_sufficient?(solution, :basic),
        solution: solution,
        tier: "basic",
        cost: calculate_ai_cost(:basic, response.data[:usage]),
        confidence: response.data[:confidence] || 0.7,
        analysis: response.data
      }
    else
      { sufficient: false, tier: "basic", cost: 0 }
    end
  end

  def pro_ai_analysis(context, tier_info)
    # Pro Tier: 고급 분석 + 수식 생성
    bridge = ExcelLLMBridgeService.new(@excel_file)

    # 더 상세한 컨텍스트 생성
    problem_context = bridge.create_problem_context(
      describe_errors(context[:errors]),
      max_tokens: 4000,  # Pro는 더 많은 토큰
      include_formulas: true,
      include_patterns: true
    )

    ai_service = UnifiedAiService.new(tier_info[:tier])

    # 멀티스텝 분석
    steps = []

    # Step 1: 오류 진단
    diagnosis = ai_service.analyze_excel(
      @excel_file,
      "Diagnose these Excel errors in detail: #{problem_context[:problem]}",
      problem_context
    )
    steps << diagnosis if diagnosis.success?

    # Step 2: 해결책 생성
    if diagnosis.success?
      solution_prompt = "Generate specific formulas and steps to fix: #{diagnosis.data[:content]}"
      solution = ai_service.analyze_excel(
        @excel_file,
        solution_prompt,
        problem_context
      )
      steps << solution if solution.success?
    end

    if steps.all?(&:success?)
      parsed_solution = bridge.parse_llm_solution(
        steps.map { |s| s.data[:content] }.join("\n\n")
      )

      {
        sufficient: is_solution_sufficient?(parsed_solution, :pro),
        solution: enhance_solution_with_formulas(parsed_solution),
        tier: "pro",
        cost: calculate_ai_cost(:pro, aggregate_usage(steps)),
        confidence: calculate_confidence(steps),
        analysis: { steps: steps.map(&:data) }
      }
    else
      { sufficient: false, tier: "pro", cost: 0 }
    end
  end

  def enterprise_ai_analysis(context, tier_info)
    # Enterprise Tier: 전체 분석 + 시뮬레이션
    {
      sufficient: true,  # Enterprise는 항상 충분
      solution: {
        type: "comprehensive",
        includes_code_execution: false,  # 아직은 false
        capabilities: [
          "complex_formula_generation",
          "data_transformation_scripts",
          "automated_fixes",
          "what_if_analysis"
        ]
      },
      tier: "enterprise",
      cost: 0,  # Enterprise는 월정액
      confidence: 0.95
    }
  end

  def requires_code_execution?(analysis)
    return false unless analysis

    # Code Interpreter가 필요한 패턴 검사
    patterns = [
      "bulk_data_transformation",
      "complex_calculations",
      "pivot_table_generation",
      "custom_formula_creation",
      "data_simulation",
      "what_if_analysis",
      "machine_learning_analysis"
    ]

    detected_patterns = detect_required_patterns(analysis)

    (detected_patterns & patterns).any?
  end

  def detect_required_patterns(analysis)
    patterns = []

    # 분석 결과에서 패턴 추출
    if analysis[:steps]
      analysis[:steps].each do |step|
        content = step[:content].to_s.downcase

        patterns << "bulk_data_transformation" if content.include?("transform") || content.include?("convert")
        patterns << "complex_calculations" if content.include?("calculate") || content.include?("compute")
        patterns << "pivot_table_generation" if content.include?("pivot")
        patterns << "custom_formula_creation" if content.include?("create formula")
        patterns << "data_simulation" if content.include?("simulate") || content.include?("forecast")
        patterns << "what_if_analysis" if content.include?("what if") || content.include?("scenario")
      end
    end

    patterns.uniq
  end

  def calculate_execution_cost
    # Code Interpreter 실행 비용 계산
    base_cost = 0.1  # 기본 비용

    # 파일 크기에 따른 추가 비용
    file_size_mb = @excel_file.file_size.to_f / (1024 * 1024)
    size_multiplier = case file_size_mb
    when 0..10 then 1.0
    when 10..50 then 1.5
    when 50..100 then 2.0
    else 3.0
    end

    # 복잡도에 따른 추가 비용
    complexity_multiplier = calculate_complexity_multiplier

    (base_cost * size_multiplier * complexity_multiplier).round(2)
  end

  def calculate_complexity_multiplier
    complexity = 1.0

    if @excel_file.analysis_result
      result = @excel_file.analysis_result

      # 시트 수
      sheets = result["sheets"]&.size || 1
      complexity += (sheets - 1) * 0.1

      # 수식 복잡도
      total_formulas = result["summary"]["total_formulas"] || 0
      complexity += (total_formulas / 1000.0)

      # 오류 수
      errors = result["errors"]&.size || 0
      complexity += (errors / 10.0)
    end

    [ complexity, 5.0 ].min  # 최대 5배
  end

  def available_code_execution_features
    {
      data_transformation: {
        description: "대량 데이터 변환 및 정리",
        examples: [ "피벗 테이블 생성", "데이터 병합", "중복 제거" ]
      },
      formula_generation: {
        description: "복잡한 수식 자동 생성",
        examples: [ "조건부 집계", "다차원 LOOKUP", "배열 수식" ]
      },
      analysis_automation: {
        description: "자동화된 분석 실행",
        examples: [ "통계 분석", "트렌드 예측", "이상치 탐지" ]
      },
      visualization: {
        description: "차트 및 시각화 생성",
        examples: [ "동적 차트", "대시보드", "히트맵" ]
      }
    }
  end

  def can_auto_fix_ref_error?(error)
    # 참조 오류 자동 수정 가능 여부
    error[:formula] && !error[:formula].include?("INDIRECT")
  end

  def suggest_value_fix(error)
    # 값 오류에 대한 자동 수정 제안
    {
      original: error[:formula],
      suggested: wrap_with_error_handling(error[:formula]),
      confidence: 0.8
    }
  end

  def wrap_with_error_handling(formula)
    # 수식을 오류 처리로 감싸기
    "=IFERROR(#{formula}, \"\")"
  end

  def can_auto_convert_types?(error)
    # 타입 자동 변환 가능 여부
    error[:expected_type] && error[:found_types].size == 1
  end

  def describe_errors(errors)
    descriptions = errors.map do |error|
      "#{error[:type]} error at #{error[:location]}"
    end

    "Excel file has the following errors: #{descriptions.join(', ')}"
  end

  def is_solution_sufficient?(solution, tier)
    return false unless solution

    case tier
    when :basic
      # Basic은 간단한 수정만 충분
      solution[:modifications]&.any? || solution[:explanations]&.any?
    when :pro
      # Pro는 수식이나 구체적인 작업 필요
      solution[:formulas]&.any? || solution[:modifications]&.any?
    when :enterprise
      # Enterprise는 항상 충분
      true
    else
      false
    end
  end

  def enhance_solution_with_formulas(solution)
    # Pro 솔루션에 수식 강화
    solution[:enhanced_formulas] = solution[:formulas]&.map do |formula|
      {
        original: formula,
        enhanced: optimize_formula(formula),
        explanation: explain_formula(formula)
      }
    end

    solution
  end

  def optimize_formula(formula)
    # 수식 최적화 (간단한 예시)
    optimized = formula[:formula]

    # VLOOKUP을 INDEX/MATCH로 변환
    if optimized.include?("VLOOKUP")
      optimized = convert_vlookup_to_index_match(optimized)
    end

    optimized
  end

  def convert_vlookup_to_index_match(formula)
    # VLOOKUP을 더 효율적인 INDEX/MATCH로 변환
    formula.gsub(/VLOOKUP\(([^,]+),([^,]+),([^,]+),([^)]+)\)/) do
      lookup_value = $1
      table_array = $2
      col_index = $3
      range_lookup = $4

      "INDEX(#{table_array}, MATCH(#{lookup_value}, INDEX(#{table_array}, 0, 1), #{range_lookup}), #{col_index})"
    end
  end

  def explain_formula(formula)
    # 수식 설명 생성
    case formula[:formula]
    when /SUM/i
      "합계를 계산합니다"
    when /VLOOKUP|INDEX.*MATCH/i
      "데이터를 조회합니다"
    when /IF/i
      "조건에 따라 다른 값을 반환합니다"
    else
      "데이터를 처리합니다"
    end
  end

  def calculate_ai_cost(tier, usage)
    return 0 unless usage

    # 토큰당 비용 (예시)
    costs = {
      basic: 0.0001,
      pro: 0.0003,
      enterprise: 0  # 월정액
    }

    total_tokens = (usage[:prompt_tokens] || 0) + (usage[:completion_tokens] || 0)
    total_tokens * costs[tier]
  end

  def aggregate_usage(steps)
    usage = { prompt_tokens: 0, completion_tokens: 0 }

    steps.each do |step|
      if step.data[:usage]
        usage[:prompt_tokens] += step.data[:usage][:prompt_tokens] || 0
        usage[:completion_tokens] += step.data[:usage][:completion_tokens] || 0
      end
    end

    usage
  end

  def calculate_confidence(steps)
    confidences = steps.map { |s| s.data[:confidence] || 0.7 }.compact
    confidences.empty? ? 0.7 : confidences.sum / confidences.size
  end

  def calculate_static_confidence(solutions, errors)
    return 0.0 if errors.empty?

    solved_count = solutions.keys.size
    total_count = errors.size

    (solved_count.to_f / total_count).round(2)
  end
end
