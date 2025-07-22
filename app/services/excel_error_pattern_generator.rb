# frozen_string_literal: true

# Excel 오류 패턴을 자동으로 생성하는 서비스
# 규칙 기반으로 수백~수천 개의 패턴 변형 생성
class ExcelErrorPatternGenerator
  
  # 오류 타입별 패턴 정의
  ERROR_PATTERNS = {
    '#REF!' => {
      base_causes: [
        'deleted_cell', 'deleted_row', 'deleted_column', 'deleted_sheet',
        'invalid_range', 'moved_reference', 'broken_link', 'missing_workbook'
      ],
      formulas: ['VLOOKUP', 'HLOOKUP', 'INDEX', 'MATCH', 'OFFSET', 'INDIRECT', 'SUMIF'],
      contexts: ['data_validation', 'pivot_table', 'chart_source', 'named_range'],
      variations: lambda do |formula, cause, context|
        [
          "#{formula} 함수에서 #{cause} 오류가 발생했습니다",
          "#{context}에서 #{formula}를 사용할 때 #{cause} 문제",
          "#{cause}로 인한 #{formula} 참조 오류",
          "#{formula}에서 참조하는 셀이 #{cause}되었습니다",
          "#{context} 작업 중 #{formula} 함수가 #{cause} 오류를 반환합니다"
        ]
      end
    },
    
    '#VALUE!' => {
      base_causes: [
        'wrong_data_type', 'text_in_number_field', 'date_format_mismatch',
        'array_size_mismatch', 'invalid_argument', 'empty_cell_reference',
        'special_character', 'locale_mismatch'
      ],
      formulas: ['SUM', 'AVERAGE', 'VLOOKUP', 'IF', 'CONCATENATE', 'DATE', 'TEXT'],
      contexts: ['calculation', 'data_import', 'formula_copy', 'cell_formatting'],
      variations: lambda do |formula, cause, context|
        [
          "#{formula}에서 #{cause} 때문에 #VALUE! 오류",
          "#{context} 중 #{formula} 함수가 #{cause}를 처리할 수 없습니다",
          "#{cause}로 인해 #{formula} 계산 불가",
          "#{formula} 함수의 인수가 #{cause}입니다",
          "#{context}에서 #{cause} 문제로 #{formula} 오류 발생"
        ]
      end
    },
    
    '#DIV/0!' => {
      base_causes: [
        'zero_denominator', 'empty_cell_division', 'average_of_empty_range',
        'calculated_zero', 'filtered_empty_result', 'conditional_zero'
      ],
      formulas: ['AVERAGE', 'AVERAGEIF', 'DIVIDE', 'MOD', 'RATE', 'IRR'],
      contexts: ['financial_calculation', 'statistical_analysis', 'ratio_calculation'],
      variations: lambda do |formula, cause, context|
        [
          "#{formula}에서 #{cause}로 0으로 나누기 오류",
          "#{context}의 #{formula} 계산 시 #{cause} 발생",
          "#{cause} 때문에 #{formula}가 #DIV/0! 반환",
          "#{formula} 함수에서 분모가 #{cause}입니다"
        ]
      end
    },
    
    '#N/A' => {
      base_causes: [
        'lookup_value_not_found', 'exact_match_missing', 'sorted_data_required',
        'range_lookup_error', 'missing_data', 'case_sensitivity', 'trailing_spaces'
      ],
      formulas: ['VLOOKUP', 'HLOOKUP', 'MATCH', 'LOOKUP', 'XLOOKUP'],
      contexts: ['data_lookup', 'report_generation', 'data_validation', 'cross_reference'],
      variations: lambda do |formula, cause, context|
        [
          "#{formula}에서 #{cause}로 값을 찾을 수 없습니다",
          "#{context} 중 #{formula}가 #{cause} 때문에 #N/A 반환",
          "#{cause}로 인해 #{formula} 조회 실패",
          "#{formula} 함수가 #{cause}를 찾지 못했습니다"
        ]
      end
    },
    
    'circular_reference' => {
      base_causes: [
        'direct_self_reference', 'indirect_loop', 'multi_cell_loop',
        'cross_sheet_loop', 'named_range_loop', 'array_formula_loop'
      ],
      formulas: ['SUM', 'AVERAGE', 'COUNT', 'ANY_FORMULA'],
      contexts: ['budget_model', 'iterative_calculation', 'dependency_chain'],
      variations: lambda do |formula, cause, context|
        [
          "#{formula}에서 #{cause}로 순환 참조 발생",
          "#{context}의 #{formula}가 #{cause} 생성",
          "#{cause} 때문에 순환 참조 오류",
          "#{formula} 수식이 자기 자신을 참조합니다 (#{cause})"
        ]
      end
    }
  }.freeze
  
  # 추가 패턴: 데이터 타입 불일치
  DATA_TYPE_PATTERNS = {
    'type_mismatch' => {
      types: ['number', 'text', 'date', 'boolean', 'error', 'empty'],
      operations: ['arithmetic', 'concatenation', 'comparison', 'lookup'],
      scenarios: [
        'CSV 가져오기 후 숫자가 텍스트로 저장됨',
        '날짜 형식이 시스템 설정과 다름',
        '수식 복사 시 상대 참조 오류',
        '병합된 셀에서 계산 시도'
      ]
    }
  }.freeze
  
  def call
    patterns = []
    
    # 기본 오류 패턴 생성
    patterns.concat(generate_error_patterns)
    
    # 데이터 타입 패턴 생성
    patterns.concat(generate_data_type_patterns)
    
    # 복합 오류 패턴 생성
    patterns.concat(generate_compound_patterns)
    
    # 버전별 호환성 패턴
    patterns.concat(generate_version_patterns)
    
    {
      success: true,
      data: {
        patterns: patterns,
        count: patterns.size,
        categories: categorize_patterns(patterns)
      }
    }
  end
  
  private
  
  def generate_error_patterns
    patterns = []
    
    ERROR_PATTERNS.each do |error_type, config|
      config[:formulas].each do |formula|
        config[:base_causes].each do |cause|
          config[:contexts].each do |context|
            variations = config[:variations].call(formula, cause, context)
            
            variations.each do |question|
              patterns << {
                question: question,
                answer: generate_solution(error_type, formula, cause, context),
                tags: [error_type, formula, cause, context],
                category: 'error_pattern',
                auto_generated: true,
                confidence: 0.9
              }
            end
          end
        end
      end
    end
    
    patterns
  end
  
  def generate_data_type_patterns
    patterns = []
    
    DATA_TYPE_PATTERNS.each do |pattern_type, config|
      config[:scenarios].each do |scenario|
        config[:types].each do |data_type|
          config[:operations].each do |operation|
            question = "#{scenario}에서 #{data_type} 타입을 #{operation} 작업할 때 오류"
            
            patterns << {
              question: question,
              answer: generate_type_solution(pattern_type, data_type, operation, scenario),
              tags: [pattern_type, data_type, operation],
              category: 'data_type_pattern',
              auto_generated: true,
              confidence: 0.85
            }
          end
        end
      end
    end
    
    patterns
  end
  
  def generate_compound_patterns
    patterns = []
    
    # 복합 오류 시나리오
    compound_scenarios = [
      {
        description: "VLOOKUP이 #N/A를 반환하고, 이를 SUM이 처리하지 못해 #VALUE! 발생",
        primary_error: '#N/A',
        secondary_error: '#VALUE!',
        solution: "IFERROR나 IFNA로 오류를 처리한 후 계산하세요"
      },
      {
        description: "피벗 테이블 소스 데이터에서 #REF! 오류로 인한 전체 실패",
        primary_error: '#REF!',
        secondary_error: 'pivot_refresh_failed',
        solution: "소스 데이터의 참조 오류를 먼저 수정한 후 피벗 테이블을 새로고침하세요"
      }
    ]
    
    compound_scenarios.each do |scenario|
      patterns << {
        question: scenario[:description],
        answer: scenario[:solution],
        tags: [scenario[:primary_error], scenario[:secondary_error], 'compound_error'],
        category: 'compound_pattern',
        auto_generated: true,
        confidence: 0.8
      }
    end
    
    patterns
  end
  
  def generate_version_patterns
    patterns = []
    
    version_issues = {
      'Excel 365' => {
        new_functions: ['XLOOKUP', 'FILTER', 'UNIQUE', 'SORT', 'SEQUENCE'],
        issues: ['동적 배열 스필 오류', '이전 버전에서 함수 인식 불가']
      },
      'Excel 2019' => {
        missing: ['XLOOKUP', 'LET', 'LAMBDA'],
        issues: ['최신 함수 사용 불가', '대체 함수 필요']
      },
      'Excel 2016' => {
        limitations: ['Power Query 제한', 'Get & Transform 미지원'],
        issues: ['데이터 모델 호환성', '일부 차트 타입 미지원']
      }
    }
    
    version_issues.each do |version, config|
      config[:issues].each do |issue|
        if config[:new_functions]
          config[:new_functions].each do |func|
            patterns << {
              question: "#{version}에서 #{func} 함수 사용 시 #{issue}",
              answer: generate_version_solution(version, func, issue),
              tags: [version, func, 'compatibility'],
              category: 'version_pattern',
              auto_generated: true,
              confidence: 0.95
            }
          end
        end
      end
    end
    
    patterns
  end
  
  def generate_solution(error_type, formula, cause, context)
    base_solutions = {
      '#REF!' => [
        "1. #{formula} 함수의 참조 범위를 확인하세요",
        "2. 삭제된 셀이나 시트를 복구하거나 참조를 수정하세요",
        "3. IFERROR(#{formula}(...), \"기본값\")로 오류를 처리하세요"
      ],
      '#VALUE!' => [
        "1. #{formula} 함수의 모든 인수가 올바른 데이터 타입인지 확인하세요",
        "2. 텍스트를 숫자로 변환: VALUE() 함수 사용",
        "3. 날짜 형식 통일: TEXT() 또는 DATEVALUE() 사용"
      ],
      '#DIV/0!' => [
        "1. IF(분모=0, 0, #{formula}(...))로 0 체크를 추가하세요",
        "2. IFERROR(#{formula}(...), 0)로 오류 처리",
        "3. 빈 셀이나 0 값을 확인하고 수정하세요"
      ],
      '#N/A' => [
        "1. #{formula}의 조회 값이 정확한지 확인 (대소문자, 공백)",
        "2. 정확히 일치 옵션을 FALSE로 설정했는지 확인",
        "3. IFNA(#{formula}(...), \"찾을 수 없음\")로 처리"
      ],
      'circular_reference' => [
        "1. 수식 추적 도구로 순환 참조 경로 확인",
        "2. 자기 참조를 제거하고 다른 셀 참조로 변경",
        "3. 반복 계산이 필요한 경우 Excel 옵션에서 활성화"
      ]
    }
    
    solutions = base_solutions[error_type] || ["일반적인 해결 방법을 시도하세요"]
    
    # 컨텍스트별 추가 조언
    context_advice = {
      'pivot_table' => "\n\n💡 피벗 테이블 관련: 소스 데이터를 수정한 후 피벗 테이블을 새로고침하세요.",
      'data_validation' => "\n\n💡 데이터 유효성 검사: 유효성 규칙이 현재 데이터와 일치하는지 확인하세요.",
      'financial_calculation' => "\n\n💡 재무 계산: 모든 값이 숫자 형식이고 통화 단위가 일치하는지 확인하세요."
    }
    
    solution_text = solutions.join("\n")
    solution_text += context_advice[context.to_sym] if context_advice[context.to_sym]
    
    solution_text
  end
  
  def generate_type_solution(pattern_type, data_type, operation, scenario)
    solutions = {
      'number' => {
        'arithmetic' => "VALUE() 함수로 텍스트를 숫자로 변환 후 계산",
        'comparison' => "숫자 형식을 통일한 후 비교 연산 수행"
      },
      'text' => {
        'concatenation' => "CONCATENATE() 또는 & 연산자 사용",
        'lookup' => "TRIM()과 CLEAN()으로 텍스트 정리 후 조회"
      },
      'date' => {
        'arithmetic' => "DATE() 함수로 날짜를 표준화한 후 계산",
        'comparison' => "DATEVALUE()로 텍스트를 날짜로 변환"
      }
    }
    
    base_solution = solutions.dig(data_type, operation) || "데이터 타입을 확인하고 적절히 변환하세요"
    
    """#{scenario} 해결 방법:
    
1. #{base_solution}
2. 데이터 타입 확인: TYPE() 함수 사용
3. 일괄 변환: 데이터 > 텍스트 나누기 기능 활용
4. 형식 통일: 셀 서식을 동일하게 설정

예방법:
- 데이터 가져오기 시 형식 지정
- Power Query로 데이터 타입 사전 정의
- 데이터 유효성 검사로 입력 제한"""
  end
  
  def generate_version_solution(version, function_name, issue)
    alternatives = {
      'XLOOKUP' => "VLOOKUP 또는 INDEX/MATCH 조합 사용",
      'FILTER' => "자동 필터 또는 고급 필터 사용",
      'UNIQUE' => "중복 제거 기능 또는 피벗 테이블 사용",
      'SORT' => "데이터 > 정렬 메뉴 사용",
      'SEQUENCE' => "ROW() 함수와 수식 조합으로 대체"
    }
    
    """#{version}에서 #{function_name} 관련 문제 해결:
    
문제: #{issue}

해결 방법:
1. 대체 함수 사용: #{alternatives[function_name] || '이전 버전 호환 함수 검색'}
2. 조건부 수식: =IF(ISERROR(#{function_name}(...)), 대체수식, #{function_name}(...))
3. VBA 매크로로 기능 구현
4. 파일을 .xlsx 형식으로 저장하여 호환성 모드 해제

장기 해결책:
- 최신 Excel 버전으로 업그레이드
- 모든 사용자의 Excel 버전 통일
- 호환성 검사 도구 실행"""
  end
  
  def categorize_patterns(patterns)
    categories = {}
    
    patterns.each do |pattern|
      category = pattern[:category]
      categories[category] ||= []
      categories[category] << pattern
    end
    
    categories.transform_values(&:count)
  end
end