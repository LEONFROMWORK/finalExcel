# frozen_string_literal: true

# AI를 활용한 Excel 오류 패턴 합성 서비스
# 기존 패턴을 기반으로 새로운 변형과 엣지 케이스 생성
class AiPatternSynthesizer
  
  attr_reader :base_patterns, :ai_service, :tier
  
  def initialize(base_patterns: nil, tier: :basic)
    @base_patterns = base_patterns || fetch_existing_patterns
    @tier = tier
    @ai_service = UnifiedAiService.new(tier)
  end
  
  def call
    synthesized_patterns = []
    
    # 1. 기존 패턴 변형 생성
    synthesized_patterns.concat(generate_variations)
    
    # 2. 엣지 케이스 생성
    synthesized_patterns.concat(generate_edge_cases)
    
    # 3. 도메인별 특화 패턴
    synthesized_patterns.concat(generate_domain_specific_patterns)
    
    # 4. 복합 오류 시나리오
    synthesized_patterns.concat(generate_compound_scenarios)
    
    # 5. 중복 제거 및 품질 검증
    unique_patterns = deduplicate_patterns(synthesized_patterns)
    validated_patterns = validate_patterns(unique_patterns)
    
    {
      success: true,
      data: {
        patterns: validated_patterns,
        count: validated_patterns.size,
        synthesis_stats: {
          variations: count_by_type(validated_patterns, 'variation'),
          edge_cases: count_by_type(validated_patterns, 'edge_case'),
          domain_specific: count_by_type(validated_patterns, 'domain'),
          compound: count_by_type(validated_patterns, 'compound')
        }
      }
    }
  rescue StandardError => e
    Rails.logger.error "Pattern synthesis failed: #{e.message}"
    { success: false, error: e.message }
  end
  
  private
  
  def fetch_existing_patterns
    # Knowledge Base에서 기존 패턴 가져오기
    qa_pairs = KnowledgeBase::QaPair.where('question LIKE ? OR question LIKE ?', '%error%', '%오류%')
                                    .limit(100)
    
    qa_pairs.map do |qa|
      {
        question: qa.question,
        answer: qa.answer,
        source: qa.source,
        tags: extract_tags(qa.question)
      }
    end
  end
  
  def generate_variations
    variations = []
    
    @base_patterns.each_slice(10) do |pattern_batch|
      prompt = build_variation_prompt(pattern_batch)
      
      response = @ai_service.generate_text(
        prompt: prompt,
        max_tokens: 2000,
        temperature: 0.8  # 창의성 증가
      )
      
      if response.success?
        parsed_variations = parse_ai_variations(response.data[:content])
        variations.concat(parsed_variations)
      end
    end
    
    variations
  end
  
  def build_variation_prompt(patterns)
    examples = patterns.map { |p| "Q: #{p[:question]}\nA: #{p[:answer]}" }.join("\n\n")
    
    <<~PROMPT
      다음은 Excel 오류 관련 Q&A 예시입니다:
      
      #{examples}
      
      위 패턴을 기반으로 비슷하지만 다른 상황의 Excel 오류 Q&A를 10개 생성해주세요.
      
      요구사항:
      1. 같은 오류 타입이지만 다른 함수나 상황
      2. 실제 사용자가 겪을 만한 구체적인 시나리오
      3. 해결책은 구체적이고 실행 가능해야 함
      4. 한국어와 영어 혼용 가능
      
      형식:
      Q: [질문]
      A: [답변]
      TAGS: [오류타입, 함수명, 상황]
    PROMPT
  end
  
  def generate_edge_cases
    edge_cases = []
    
    # 극단적인 케이스 정의
    extreme_scenarios = [
      {
        type: 'deeply_nested',
        description: '10단계 이상 중첩된 함수',
        example: '=IF(IF(IF(IF(IF(IF(IF(IF(IF(IF(A1>0,1,0)...)))))))'
      },
      {
        type: 'massive_array',
        description: '100만 개 이상의 셀 참조',
        example: '=SUM(A1:CV1000000)'
      },
      {
        type: 'unicode_chaos',
        description: '특수 문자와 이모지가 포함된 데이터',
        example: '=VLOOKUP("😀🎉", A:B, 2, FALSE)'
      },
      {
        type: 'circular_nightmare',
        description: '다중 시트 간 복잡한 순환 참조',
        example: 'Sheet1!A1 → Sheet2!B1 → Sheet3!C1 → Sheet1!A1'
      },
      {
        type: 'volatile_overload',
        description: '휘발성 함수 과다 사용',
        example: '1000개의 NOW() 함수가 동시에 실행'
      }
    ]
    
    extreme_scenarios.each do |scenario|
      prompt = <<~PROMPT
        Excel에서 #{scenario[:description]} 상황의 오류 Q&A를 생성하세요.
        
        예시: #{scenario[:example]}
        
        다음을 포함해주세요:
        1. 이런 극단적 상황이 발생하는 실제 시나리오
        2. 발생하는 구체적인 오류 메시지
        3. 성능 문제와 해결 방법
        4. 대안적인 접근 방법
        
        5개의 Q&A를 생성하세요.
      PROMPT
      
      response = @ai_service.generate_text(prompt: prompt, max_tokens: 1500)
      
      if response.success?
        parsed_cases = parse_ai_edge_cases(response.data[:content], scenario[:type])
        edge_cases.concat(parsed_cases)
      end
    end
    
    edge_cases
  end
  
  def generate_domain_specific_patterns
    domains = {
      finance: {
        functions: ['NPV', 'IRR', 'PMT', 'RATE', 'PV', 'FV'],
        scenarios: ['대출 계산', '투자 수익률', '재무제표', '환율 계산']
      },
      accounting: {
        functions: ['SUMIF', 'SUMIFS', 'SUBTOTAL', 'ROUND'],
        scenarios: ['잔액 불일치', '반올림 오류', '세금 계산', '감가상각']
      },
      data_analysis: {
        functions: ['PIVOT', 'FILTER', 'UNIQUE', 'XLOOKUP'],
        scenarios: ['대용량 데이터', '중복 제거', '동적 보고서', '실시간 대시보드']
      },
      hr: {
        functions: ['COUNTIF', 'AVERAGEIF', 'NETWORKDAYS', 'DATEDIF'],
        scenarios: ['근태 관리', '급여 계산', '휴가 일수', '성과 평가']
      }
    }
    
    domain_patterns = []
    
    domains.each do |domain, config|
      prompt = build_domain_prompt(domain, config)
      response = @ai_service.generate_text(prompt: prompt, max_tokens: 2000)
      
      if response.success?
        patterns = parse_domain_patterns(response.data[:content], domain)
        domain_patterns.concat(patterns)
      end
    end
    
    domain_patterns
  end
  
  def build_domain_prompt(domain, config)
    <<~PROMPT
      #{domain} 분야의 Excel 오류 패턴을 생성하세요.
      
      주요 함수: #{config[:functions].join(', ')}
      주요 시나리오: #{config[:scenarios].join(', ')}
      
      각 시나리오별로 2개씩, 총 8개의 Q&A를 생성하세요.
      
      포함 사항:
      1. 도메인 특화 용어 사용
      2. 실제 업무에서 발생하는 문제
      3. 규정이나 표준 관련 이슈
      4. 도메인별 베스트 프랙티스
      
      형식:
      Q: [질문]
      A: [답변]
      DOMAIN: #{domain}
      SCENARIO: [시나리오]
    PROMPT
  end
  
  def generate_compound_scenarios
    # 여러 오류가 연쇄적으로 발생하는 복합 시나리오
    compound_templates = [
      {
        primary: '#N/A',
        secondary: '#VALUE!',
        scenario: 'VLOOKUP 실패 후 계산 오류'
      },
      {
        primary: '#REF!',
        secondary: 'pivot_refresh_failed',
        scenario: '참조 오류로 인한 피벗 테이블 실패'
      },
      {
        primary: 'circular_reference',
        secondary: 'performance_degradation',
        scenario: '순환 참조로 인한 성능 저하'
      },
      {
        primary: 'data_type_mismatch',
        secondary: 'chart_update_failed',
        scenario: '데이터 타입 오류로 차트 업데이트 실패'
      }
    ]
    
    compound_patterns = []
    
    prompt = <<~PROMPT
      다음 복합 오류 시나리오에 대한 Q&A를 생성하세요:
      
      #{compound_templates.map { |t| "- #{t[:scenario]}: #{t[:primary]} → #{t[:secondary]}" }.join("\n")}
      
      각 시나리오별로 3개씩 Q&A를 생성하세요.
      
      포함 사항:
      1. 오류가 연쇄적으로 발생하는 과정
      2. 근본 원인 찾기
      3. 단계별 해결 방법
      4. 예방 방법
    PROMPT
    
    response = @ai_service.generate_text(prompt: prompt, max_tokens: 2500)
    
    if response.success?
      compound_patterns = parse_compound_patterns(response.data[:content])
    end
    
    compound_patterns
  end
  
  def parse_ai_variations(content)
    patterns = []
    
    # AI 응답을 파싱
    content.split(/\n\n/).each do |block|
      next unless block.include?('Q:') && block.include?('A:')
      
      question = extract_between(block, 'Q:', 'A:')
      answer = extract_between(block, 'A:', 'TAGS:')
      tags = extract_after(block, 'TAGS:')
      
      if question && answer
        patterns << {
          question: question.strip,
          answer: answer.strip,
          tags: parse_tags(tags),
          type: 'variation',
          auto_generated: true,
          confidence: 0.85
        }
      end
    end
    
    patterns
  end
  
  def parse_ai_edge_cases(content, edge_type)
    patterns = []
    
    content.split(/Q:/).each do |block|
      next if block.strip.empty?
      
      parts = block.split(/A:/)
      next unless parts.size == 2
      
      patterns << {
        question: parts[0].strip,
        answer: parts[1].strip,
        tags: [edge_type, 'edge_case'],
        type: 'edge_case',
        auto_generated: true,
        confidence: 0.8
      }
    end
    
    patterns
  end
  
  def parse_domain_patterns(content, domain)
    patterns = []
    
    content.scan(/Q: (.+?)\nA: (.+?)(?:\nDOMAIN: (.+?))?\nSCENARIO: (.+?)(?=\n\nQ:|$)/m) do |q, a, d, s|
      patterns << {
        question: q.strip,
        answer: a.strip,
        tags: [domain.to_s, s.strip.downcase.gsub(/\s+/, '_')],
        type: 'domain',
        domain: domain,
        scenario: s.strip,
        auto_generated: true,
        confidence: 0.9
      }
    end
    
    patterns
  end
  
  def parse_compound_patterns(content)
    patterns = []
    
    # 복합 패턴 파싱 로직
    current_scenario = nil
    
    content.lines.each do |line|
      if line.include?('시나리오:') || line.include?('Scenario:')
        current_scenario = line.split(':').last.strip
      elsif line.start_with?('Q:')
        question = line.sub('Q:', '').strip
        # 다음 A: 찾기 로직 필요
      end
    end
    
    patterns
  end
  
  def deduplicate_patterns(patterns)
    seen = Set.new
    unique = []
    
    patterns.each do |pattern|
      # 질문의 핵심 내용으로 중복 체크
      key = normalize_for_dedup(pattern[:question])
      
      unless seen.include?(key)
        seen.add(key)
        unique << pattern
      end
    end
    
    unique
  end
  
  def normalize_for_dedup(text)
    # 공백, 대소문자, 특수문자 정규화
    text.downcase.gsub(/\s+/, ' ').gsub(/[^\w\s가-힣]/, '').strip
  end
  
  def validate_patterns(patterns)
    patterns.select do |pattern|
      # 기본 검증
      next false if pattern[:question].length < 10
      next false if pattern[:answer].length < 20
      
      # Excel 관련 키워드 포함 확인
      excel_keywords = %w[excel 엑셀 함수 수식 formula cell 셀 error 오류]
      has_keyword = excel_keywords.any? { |kw| 
        pattern[:question].downcase.include?(kw) || 
        pattern[:answer].downcase.include?(kw) 
      }
      
      has_keyword
    end
  end
  
  def extract_tags(text)
    tags = []
    
    # 오류 타입 추출
    error_types = %w[#REF! #VALUE! #DIV/0! #N/A #NAME? #NULL! #NUM!]
    error_types.each do |error|
      tags << error if text.include?(error)
    end
    
    # 함수명 추출
    function_pattern = /\b[A-Z]+(?:IF|LOOKUP|MATCH|INDEX|SUM|COUNT|AVERAGE)\b/
    text.scan(function_pattern) { |func| tags << func }
    
    tags.uniq
  end
  
  def extract_between(text, start_marker, end_marker)
    return nil unless text.include?(start_marker)
    
    start_idx = text.index(start_marker) + start_marker.length
    end_idx = end_marker ? text.index(end_marker, start_idx) : text.length
    
    return nil unless end_idx
    
    text[start_idx...end_idx]
  end
  
  def extract_after(text, marker)
    return nil unless text.include?(marker)
    
    start_idx = text.index(marker) + marker.length
    text[start_idx..-1]
  end
  
  def parse_tags(tag_string)
    return [] unless tag_string
    
    tag_string.split(',').map(&:strip).reject(&:empty?)
  end
  
  def count_by_type(patterns, type)
    patterns.count { |p| p[:type] == type }
  end
end