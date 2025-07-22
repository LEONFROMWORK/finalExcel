# frozen_string_literal: true

# AI 생성 패턴의 할루시네이션을 감지하고 검증하는 서비스
class AiHallucinationDetector
  
  # 할루시네이션 감지 규칙
  HALLUCINATION_RULES = {
    # Excel 함수 검증
    invalid_functions: {
      check: :validate_excel_functions,
      weight: 0.3,
      description: '존재하지 않는 Excel 함수 사용'
    },
    
    # 문법 오류
    syntax_errors: {
      check: :validate_formula_syntax,
      weight: 0.25,
      description: '잘못된 Excel 수식 문법'
    },
    
    # 논리적 모순
    logical_contradictions: {
      check: :check_logical_consistency,
      weight: 0.2,
      description: '질문과 답변의 논리적 불일치'
    },
    
    # 불가능한 해결책
    impossible_solutions: {
      check: :validate_solution_feasibility,
      weight: 0.15,
      description: '실행 불가능한 해결책 제시'
    },
    
    # 버전 호환성
    version_incompatibility: {
      check: :check_version_compatibility,
      weight: 0.1,
      description: '버전 간 호환되지 않는 기능'
    }
  }.freeze
  
  # 알려진 Excel 함수 목록
  VALID_EXCEL_FUNCTIONS = %w[
    SUM AVERAGE COUNT MAX MIN IF IFS VLOOKUP HLOOKUP XLOOKUP
    INDEX MATCH OFFSET INDIRECT SUMIF SUMIFS COUNTIF COUNTIFS
    AVERAGEIF AVERAGEIFS AND OR NOT CONCATENATE TEXTJOIN
    LEFT RIGHT MID LEN TRIM CLEAN SUBSTITUTE REPLACE
    DATE TIME NOW TODAY YEAR MONTH DAY HOUR MINUTE SECOND
    NETWORKDAYS WORKDAY DATEDIF WEEKDAY DATEVALUE TIMEVALUE
    ROUND ROUNDUP ROUNDDOWN INT TRUNC CEILING FLOOR
    ABS SIGN SQRT POWER EXP LN LOG LOG10 MOD RAND RANDBETWEEN
    NPV IRR XNPV XIRR PMT PPMT IPMT RATE PV FV
    FILTER SORT SORTBY UNIQUE SEQUENCE RANDARRAY
    LET LAMBDA SCAN REDUCE MAP MAKEARRAY BYROW BYCOL
  ].freeze
  
  attr_reader :pattern, :validation_results
  
  def initialize(pattern)
    @pattern = pattern
    @validation_results = {}
  end
  
  def call
    # 각 검증 규칙 실행
    HALLUCINATION_RULES.each do |rule_name, rule_config|
      result = send(rule_config[:check])
      @validation_results[rule_name] = result
    end
    
    # 전체 점수 계산
    overall_score = calculate_overall_score
    hallucination_detected = overall_score < 0.7
    
    # 상세 분석 결과
    analysis = {
      pattern_id: @pattern.id,
      overall_score: overall_score,
      hallucination_detected: hallucination_detected,
      validation_results: @validation_results,
      issues: collect_issues,
      recommendations: generate_recommendations
    }
    
    # 결과 저장
    save_validation_result(analysis)
    
    {
      success: true,
      data: {
        valid: !hallucination_detected,
        score: overall_score,
        analysis: analysis
      }
    }
  end
  
  private
  
  def validate_excel_functions
    issues = []
    score = 1.0
    
    # 답변에서 함수 추출
    functions_in_answer = extract_excel_functions(@pattern.answer)
    
    functions_in_answer.each do |func|
      unless VALID_EXCEL_FUNCTIONS.include?(func.upcase)
        issues << "알 수 없는 Excel 함수: #{func}"
        score -= 0.2
      end
    end
    
    # 함수 시그니처 검증
    formula_patterns = extract_formulas(@pattern.answer)
    formula_patterns.each do |formula|
      validation = validate_formula_structure(formula)
      unless validation[:valid]
        issues << validation[:error]
        score -= 0.1
      end
    end
    
    {
      valid: issues.empty?,
      score: [score, 0].max,
      issues: issues
    }
  end
  
  def validate_formula_syntax
    issues = []
    score = 1.0
    
    formulas = extract_formulas(@pattern.answer)
    
    formulas.each do |formula|
      # 괄호 균형 검사
      if !balanced_parentheses?(formula)
        issues << "괄호가 맞지 않음: #{formula}"
        score -= 0.3
      end
      
      # 인용부호 균형 검사
      if !balanced_quotes?(formula)
        issues << "인용부호가 맞지 않음: #{formula}"
        score -= 0.2
      end
      
      # 셀 참조 유효성
      if !valid_cell_references?(formula)
        issues << "잘못된 셀 참조: #{formula}"
        score -= 0.2
      end
    end
    
    {
      valid: issues.empty?,
      score: [score, 0].max,
      issues: issues
    }
  end
  
  def check_logical_consistency
    issues = []
    score = 1.0
    
    # 오류 타입과 해결책의 일치성 검사
    if @pattern.error_type.present?
      case @pattern.error_type
      when 'ref_error'
        unless @pattern.answer.match?(/참조|reference|삭제|delete|시트|sheet/i)
          issues << "#REF! 오류인데 참조 관련 해결책이 없음"
          score -= 0.3
        end
      when 'value_error'
        unless @pattern.answer.match?(/타입|type|형식|format|숫자|number|텍스트|text/i)
          issues << "#VALUE! 오류인데 데이터 타입 해결책이 없음"
          score -= 0.3
        end
      when 'div_zero'
        unless @pattern.answer.match?(/0|zero|나누기|division|IF|IFERROR/i)
          issues << "#DIV/0! 오류인데 0 나누기 해결책이 없음"
          score -= 0.3
        end
      end
    end
    
    # 질문의 키워드가 답변에 반영되었는지
    question_keywords = extract_keywords(@pattern.question)
    answer_keywords = extract_keywords(@pattern.answer)
    
    keyword_overlap = (question_keywords & answer_keywords).size.to_f / question_keywords.size
    if keyword_overlap < 0.3
      issues << "질문과 답변의 연관성이 낮음 (#{(keyword_overlap * 100).round}%)"
      score -= 0.2
    end
    
    {
      valid: issues.empty?,
      score: [score, 0].max,
      issues: issues
    }
  end
  
  def validate_solution_feasibility
    issues = []
    score = 1.0
    
    # 불가능한 작업 패턴 검사
    impossible_patterns = [
      {
        pattern: /순환.*참조.*허용|circular.*reference.*allow/i,
        message: "순환 참조는 특별한 설정 없이는 허용되지 않음"
      },
      {
        pattern: /무한.*행|무한.*열|infinite.*row|infinite.*column/i,
        message: "Excel은 유한한 행/열만 지원"
      },
      {
        pattern: /실시간.*주식|real.*time.*stock/i,
        message: "Excel 기본 기능으로는 실시간 데이터 불가"
      }
    ]
    
    impossible_patterns.each do |check|
      if @pattern.answer.match?(check[:pattern])
        issues << check[:message]
        score -= 0.3
      end
    end
    
    # 과도하게 복잡한 해결책
    if @pattern.answer.length > 2000
      issues << "답변이 지나치게 길고 복잡함"
      score -= 0.1
    end
    
    {
      valid: issues.empty?,
      score: [score, 0].max,
      issues: issues
    }
  end
  
  def check_version_compatibility
    issues = []
    score = 1.0
    
    # 새 함수를 구 버전에서 사용
    new_functions = %w[XLOOKUP FILTER SORT UNIQUE LET LAMBDA]
    old_version_mentioned = @pattern.question.match?(/2016|2019|이전.*버전|old.*version/i)
    
    if old_version_mentioned
      new_functions.each do |func|
        if @pattern.answer.include?(func)
          issues << "#{func}는 Excel 365에서만 사용 가능"
          score -= 0.2
        end
      end
    end
    
    {
      valid: issues.empty?,
      score: [score, 0].max,
      issues: issues
    }
  end
  
  # 헬퍼 메서드들
  def extract_excel_functions(text)
    # Excel 함수 패턴: 대문자로 시작하고 괄호가 따라옴
    text.scan(/\b([A-Z]+(?:[A-Z.]*[A-Z]+)?)\s*\(/i).flatten.uniq
  end
  
  def extract_formulas(text)
    # = 로 시작하는 수식 추출
    text.scan(/=\s*[^,\s]+(?:\([^)]*\))?(?:[^,\n]*)?/).map(&:strip)
  end
  
  def balanced_parentheses?(formula)
    count = 0
    formula.chars.each do |char|
      count += 1 if char == '('
      count -= 1 if char == ')'
      return false if count < 0
    end
    count == 0
  end
  
  def balanced_quotes?(formula)
    # 홀수 개의 인용부호는 문제
    double_quotes = formula.count('"')
    single_quotes = formula.count("'")
    
    double_quotes.even? && single_quotes.even?
  end
  
  def valid_cell_references?(formula)
    # 셀 참조 패턴
    cell_refs = formula.scan(/\b[A-Z]+[0-9]+\b/i)
    
    cell_refs.all? do |ref|
      col_part = ref.match(/[A-Z]+/i)[0]
      row_part = ref.match(/[0-9]+/)[0]
      
      # 열은 XFD(16384)까지, 행은 1048576까지
      col_number = excel_column_to_number(col_part)
      row_number = row_part.to_i
      
      col_number <= 16384 && row_number >= 1 && row_number <= 1048576
    end
  end
  
  def excel_column_to_number(column)
    column.upcase.chars.inject(0) do |sum, char|
      sum * 26 + (char.ord - 'A'.ord + 1)
    end
  end
  
  def validate_formula_structure(formula)
    # 기본 구조 검증
    func_match = formula.match(/=\s*([A-Z]+)\s*\((.*)\)/i)
    
    unless func_match
      return { valid: false, error: "수식 구조가 올바르지 않음: #{formula}" }
    end
    
    function_name = func_match[1].upcase
    arguments = func_match[2]
    
    # 함수별 인자 검증
    case function_name
    when 'VLOOKUP'
      arg_count = arguments.split(',').size
      unless arg_count >= 3 && arg_count <= 4
        return { valid: false, error: "VLOOKUP은 3-4개의 인자가 필요함" }
      end
    when 'IF'
      arg_count = arguments.split(',').size
      unless arg_count >= 2 && arg_count <= 3
        return { valid: false, error: "IF는 2-3개의 인자가 필요함" }
      end
    end
    
    { valid: true }
  end
  
  def extract_keywords(text)
    # 중요 키워드 추출
    text.downcase
        .split(/\s+/)
        .select { |word| word.length > 3 }
        .reject { |word| stop_words.include?(word) }
  end
  
  def stop_words
    %w[this that these those have been what when where which some]
  end
  
  def calculate_overall_score
    total_score = 0.0
    total_weight = 0.0
    
    HALLUCINATION_RULES.each do |rule_name, rule_config|
      result = @validation_results[rule_name]
      next unless result
      
      score = result[:score]
      weight = rule_config[:weight]
      
      total_score += score * weight
      total_weight += weight
    end
    
    total_weight > 0 ? total_score / total_weight : 0.0
  end
  
  def collect_issues
    all_issues = []
    
    @validation_results.each do |rule_name, result|
      next unless result[:issues]&.any?
      
      all_issues.concat(result[:issues].map { |issue|
        {
          rule: rule_name,
          description: HALLUCINATION_RULES[rule_name][:description],
          issue: issue
        }
      })
    end
    
    all_issues
  end
  
  def generate_recommendations
    recommendations = []
    
    @validation_results.each do |rule_name, result|
      next if result[:valid]
      
      case rule_name
      when :invalid_functions
        recommendations << "Excel 함수명을 확인하고 올바른 함수로 수정하세요"
      when :syntax_errors
        recommendations << "수식의 괄호와 인용부호가 올바른지 확인하세요"
      when :logical_contradictions
        recommendations << "질문의 오류 타입과 답변의 해결책이 일치하는지 확인하세요"
      when :impossible_solutions
        recommendations << "제시된 해결책이 Excel에서 실제로 가능한지 검증하세요"
      when :version_incompatibility
        recommendations << "함수가 해당 Excel 버전에서 지원되는지 확인하세요"
      end
    end
    
    recommendations
  end
  
  def save_validation_result(analysis)
    # 검증 결과를 패턴의 메타데이터에 저장
    @pattern.metadata[:hallucination_check] = {
      checked_at: Time.current,
      score: analysis[:overall_score],
      detected: analysis[:hallucination_detected],
      issues_count: analysis[:issues].size
    }
    
    # 할루시네이션이 감지되면 자동으로 미승인 처리
    if analysis[:hallucination_detected]
      @pattern.approved = false
      @pattern.metadata[:auto_rejected_reason] = 'hallucination_detected'
    end
    
    @pattern.save!
  end
end