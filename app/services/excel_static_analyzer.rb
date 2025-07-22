# frozen_string_literal: true

# Excel 파일의 정적 분석을 수행하는 서비스
# Python 서비스와 연동하여 오류를 탐지하고 분석
class ExcelStaticAnalyzer < Shared::BaseClasses::ApplicationService
  
  attr_reader :excel_file, :python_client
  
  def initialize(excel_file)
    @excel_file = excel_file
    @python_client = PythonServiceClient.new
  end
  
  def detect_errors
    errors = []
    
    # 기존 분석 결과에서 오류 추출
    if @excel_file.analysis_result && @excel_file.analysis_result['errors']
      errors.concat(parse_existing_errors(@excel_file.analysis_result['errors']))
    end
    
    # 추가 정적 분석 수행
    begin
      detailed_analysis = fetch_detailed_analysis
      
      if detailed_analysis
        errors.concat(detect_formula_errors(detailed_analysis))
        errors.concat(detect_reference_errors(detailed_analysis))
        errors.concat(detect_data_consistency_errors(detailed_analysis))
        errors.concat(detect_circular_references(detailed_analysis))
      end
    rescue StandardError => e
      Rails.logger.error "Static analysis failed: #{e.message}"
    end
    
    # 중복 제거 및 정렬
    errors.uniq { |e| "#{e[:type]}_#{e[:location]}" }
          .sort_by { |e| [e[:severity], e[:location].to_s] }
  end
  
  def analyze_formulas
    analysis = {
      total_formulas: 0,
      formula_types: {},
      complexity_stats: {},
      dependencies: {},
      potential_issues: []
    }
    
    detailed_data = fetch_detailed_analysis
    return analysis unless detailed_data && detailed_data['sheets']
    
    detailed_data['sheets'].each do |sheet|
      next unless sheet['formulas']
      
      sheet['formulas'].each do |formula_info|
        analysis[:total_formulas] += 1
        
        # 수식 타입 분류
        formula_type = categorize_formula(formula_info['formula'])
        analysis[:formula_types][formula_type] ||= 0
        analysis[:formula_types][formula_type] += 1
        
        # 복잡도 분석
        complexity = calculate_formula_complexity(formula_info['formula'])
        analysis[:complexity_stats][complexity] ||= 0
        analysis[:complexity_stats][complexity] += 1
        
        # 의존성 추적
        deps = extract_dependencies(formula_info['formula'])
        if deps.any?
          analysis[:dependencies][formula_info['cell']] = deps
        end
        
        # 잠재적 문제 감지
        issues = detect_formula_issues(formula_info)
        analysis[:potential_issues].concat(issues) if issues.any?
      end
    end
    
    analysis
  end
  
  def check_data_quality
    quality_report = {
      score: 100,
      issues: [],
      recommendations: []
    }
    
    detailed_data = fetch_detailed_analysis
    return quality_report unless detailed_data
    
    # 빈 셀 검사
    empty_cells = check_empty_cells(detailed_data)
    if empty_cells[:percentage] > 20
      quality_report[:issues] << {
        type: 'high_empty_cells',
        severity: 'warning',
        details: "#{empty_cells[:percentage]}% of cells are empty"
      }
      quality_report[:score] -= 10
    end
    
    # 데이터 타입 일관성
    type_consistency = check_type_consistency(detailed_data)
    type_consistency[:issues].each do |issue|
      quality_report[:issues] << issue
      quality_report[:score] -= 5
    end
    
    # 중복 데이터
    duplicates = check_duplicates(detailed_data)
    if duplicates[:found]
      quality_report[:issues] << {
        type: 'duplicate_data',
        severity: 'info',
        details: "Found #{duplicates[:count]} duplicate rows"
      }
      quality_report[:score] -= 5
    end
    
    # 날짜 형식 검사
    date_issues = check_date_formats(detailed_data)
    quality_report[:issues].concat(date_issues)
    quality_report[:score] -= date_issues.size * 2
    
    # 점수 보정
    quality_report[:score] = [quality_report[:score], 0].max
    
    # 권장사항 생성
    quality_report[:recommendations] = generate_quality_recommendations(quality_report[:issues])
    
    quality_report
  end
  
  private
  
  def fetch_detailed_analysis
    return @detailed_analysis if defined?(@detailed_analysis)
    
    file_path = get_file_path(@excel_file)
    
    @detailed_analysis = @python_client.get_detailed_analysis(file_path, {
      include_values: true,
      include_formulas: true,
      include_formatting: true,
      check_errors: true
    })
  rescue StandardError => e
    Rails.logger.error "Failed to fetch detailed analysis: #{e.message}"
    nil
  end
  
  def parse_existing_errors(errors)
    errors.map do |error|
      {
        type: error['error_type'] || error['type'],
        location: error['location'] || error['cell'],
        message: error['message'] || error['description'],
        severity: determine_severity(error['error_type'] || error['type']),
        sheet: error['sheet'],
        formula: error['formula']
      }
    end
  end
  
  def detect_formula_errors(data)
    errors = []
    
    data['sheets']&.each do |sheet|
      sheet['formulas']&.each do |formula_info|
        # Excel 오류 패턴 검사
        if formula_info['value'] =~ /^#(REF|VALUE|NAME|DIV\/0|NULL|NUM|N\/A)!/
          errors << {
            type: formula_info['value'],
            location: formula_info['cell'],
            sheet: sheet['name'],
            formula: formula_info['formula'],
            severity: 'error',
            message: get_error_description(formula_info['value'])
          }
        end
        
        # 위험한 수식 패턴
        if risky_formula?(formula_info['formula'])
          errors << {
            type: 'risky_formula',
            location: formula_info['cell'],
            sheet: sheet['name'],
            formula: formula_info['formula'],
            severity: 'warning',
            message: "Formula may cause performance issues or errors"
          }
        end
      end
    end
    
    errors
  end
  
  def detect_reference_errors(data)
    errors = []
    all_sheets = data['sheets']&.map { |s| s['name'] } || []
    
    data['sheets']&.each do |sheet|
      sheet['formulas']&.each do |formula_info|
        # 외부 시트 참조 검사
        referenced_sheets = extract_sheet_references(formula_info['formula'])
        
        missing_sheets = referenced_sheets - all_sheets
        if missing_sheets.any?
          errors << {
            type: 'missing_sheet_reference',
            location: formula_info['cell'],
            sheet: sheet['name'],
            formula: formula_info['formula'],
            severity: 'error',
            message: "References missing sheet(s): #{missing_sheets.join(', ')}"
          }
        end
        
        # 범위 초과 참조 검사
        if out_of_bounds_reference?(formula_info['formula'], sheet)
          errors << {
            type: 'out_of_bounds_reference',
            location: formula_info['cell'],
            sheet: sheet['name'],
            formula: formula_info['formula'],
            severity: 'warning',
            message: "Formula references cells outside data range"
          }
        end
      end
    end
    
    errors
  end
  
  def detect_data_consistency_errors(data)
    errors = []
    
    data['sheets']&.each do |sheet|
      # 열별 데이터 타입 검사
      if sheet['data_types']
        sheet['data_types'].each do |column, types|
          if types['mixed'] && types['distribution'].size > 2
            errors << {
              type: 'data_type_mismatch',
              location: "Column #{column}",
              sheet: sheet['name'],
              severity: 'warning',
              message: "Mixed data types found: #{types['distribution'].keys.join(', ')}",
              expected_type: types['primary'],
              found_types: types['distribution'].keys
            }
          end
        end
      end
      
      # 헤더 누락 검사
      if sheet['headers'].nil? || sheet['headers'].any?(&:nil?)
        errors << {
          type: 'missing_headers',
          location: 'Row 1',
          sheet: sheet['name'],
          severity: 'info',
          message: "Missing or incomplete headers"
        }
      end
    end
    
    errors
  end
  
  def detect_circular_references(data)
    errors = []
    dependency_graph = build_dependency_graph(data)
    
    # 순환 참조 감지 (DFS)
    visited = {}
    rec_stack = {}
    
    dependency_graph.each_key do |cell|
      if detect_cycle(cell, dependency_graph, visited, rec_stack)
        cycle_path = find_cycle_path(cell, dependency_graph)
        
        errors << {
          type: 'circular_reference',
          location: cell,
          severity: 'error',
          message: "Circular reference detected",
          chain: cycle_path
        }
      end
    end
    
    errors
  end
  
  def build_dependency_graph(data)
    graph = {}
    
    data['sheets']&.each do |sheet|
      sheet['formulas']&.each do |formula_info|
        cell_ref = "#{sheet['name']}!#{formula_info['cell']}"
        dependencies = extract_cell_references(formula_info['formula']).map do |ref|
          ref.include!('!') ? ref : "#{sheet['name']}!#{ref}"
        end
        
        graph[cell_ref] = dependencies if dependencies.any?
      end
    end
    
    graph
  end
  
  def detect_cycle(node, graph, visited, rec_stack)
    visited[node] = true
    rec_stack[node] = true
    
    if graph[node]
      graph[node].each do |neighbor|
        if !visited[neighbor] && detect_cycle(neighbor, graph, visited, rec_stack)
          return true
        elsif rec_stack[neighbor]
          return true
        end
      end
    end
    
    rec_stack[node] = false
    false
  end
  
  def find_cycle_path(start_node, graph)
    # 순환 경로 찾기 (간단한 구현)
    path = [start_node]
    current = start_node
    
    10.times do  # 최대 10단계
      next_nodes = graph[current]
      break unless next_nodes&.any?
      
      current = next_nodes.first
      path << current
      
      break if current == start_node
    end
    
    path
  end
  
  def categorize_formula(formula)
    case formula
    when /^=SUM|AVERAGE|COUNT|MAX|MIN/i
      'aggregation'
    when /^=IF|IFS|SWITCH/i
      'conditional'
    when /^=VLOOKUP|HLOOKUP|INDEX|MATCH/i
      'lookup'
    when /^=DATE|YEAR|MONTH|DAY/i
      'date_time'
    when /^=CONCATENATE|TEXTJOIN|LEFT|RIGHT|MID/i
      'text'
    when /^=AND|OR|NOT/i
      'logical'
    else
      'other'
    end
  end
  
  def calculate_formula_complexity(formula)
    score = 0
    
    # 함수 중첩 깊이
    nesting_depth = formula.count('(')
    score += nesting_depth * 2
    
    # 함수 개수
    function_count = formula.scan(/[A-Z]+\(/).size
    score += function_count
    
    # 수식 길이
    score += formula.length / 50
    
    # 복잡도 레벨
    case score
    when 0..5 then 'simple'
    when 6..15 then 'moderate'
    when 16..30 then 'complex'
    else 'very_complex'
    end
  end
  
  def extract_dependencies(formula)
    references = []
    
    # 셀 참조 패턴
    cell_pattern = /(?:[A-Za-z_\w]+!)?[$]?[A-Z]+[$]?\d+/
    range_pattern = /(?:[A-Za-z_\w]+!)?[$]?[A-Z]+[$]?\d+:[$]?[A-Z]+[$]?\d+/
    
    # 범위 참조
    formula.scan(range_pattern) { |match| references << match }
    
    # 개별 셀 참조
    remaining = formula.gsub(range_pattern, '')
    remaining.scan(cell_pattern) { |match| references << match }
    
    references.uniq
  end
  
  def detect_formula_issues(formula_info)
    issues = []
    formula = formula_info['formula']
    
    # 휘발성 함수 사용
    volatile_functions = %w[NOW TODAY RAND RANDBETWEEN OFFSET INDIRECT]
    volatile_functions.each do |func|
      if formula.include?("#{func}(")
        issues << {
          type: 'volatile_function',
          location: formula_info['cell'],
          severity: 'info',
          message: "Uses volatile function #{func} which recalculates on every change"
        }
      end
    end
    
    # 전체 열/행 참조
    if formula =~ /[A-Z]+:[A-Z]+|[\d]+:[\d]+/
      issues << {
        type: 'full_column_reference',
        location: formula_info['cell'],
        severity: 'warning',
        message: "References entire columns/rows which may impact performance"
      }
    end
    
    issues
  end
  
  def check_empty_cells(data)
    total_cells = 0
    empty_cells = 0
    
    data['sheets']&.each do |sheet|
      if sheet['statistics']
        total_cells += sheet['statistics']['total_cells'] || 0
        empty_cells += sheet['statistics']['empty_cells'] || 0
      end
    end
    
    percentage = total_cells > 0 ? (empty_cells.to_f / total_cells * 100).round(2) : 0
    
    {
      total: total_cells,
      empty: empty_cells,
      percentage: percentage
    }
  end
  
  def check_type_consistency(data)
    issues = []
    
    data['sheets']&.each do |sheet|
      if sheet['data_types']
        sheet['data_types'].each do |column, type_info|
          if type_info['mixed'] && type_info['distribution'].size > 1
            primary_percentage = (type_info['distribution'][type_info['primary']].to_f / 
                                type_info['distribution'].values.sum * 100).round(2)
            
            if primary_percentage < 80
              issues << {
                type: 'inconsistent_data_type',
                severity: 'warning',
                location: "#{sheet['name']} - Column #{column}",
                details: "Only #{primary_percentage}% are #{type_info['primary']}"
              }
            end
          end
        end
      end
    end
    
    { issues: issues }
  end
  
  def check_duplicates(data)
    duplicate_count = 0
    found = false
    
    data['sheets']&.each do |sheet|
      if sheet['statistics'] && sheet['statistics']['duplicate_rows']
        duplicate_count += sheet['statistics']['duplicate_rows']
        found = true if sheet['statistics']['duplicate_rows'] > 0
      end
    end
    
    {
      found: found,
      count: duplicate_count
    }
  end
  
  def check_date_formats(data)
    issues = []
    
    data['sheets']&.each do |sheet|
      if sheet['date_columns']
        sheet['date_columns'].each do |column_info|
          if column_info['mixed_formats']
            issues << {
              type: 'inconsistent_date_format',
              severity: 'warning',
              location: "#{sheet['name']} - Column #{column_info['column']}",
              details: "Multiple date formats found"
            }
          end
        end
      end
    end
    
    issues
  end
  
  def generate_quality_recommendations(issues)
    recommendations = []
    
    # 그룹별 권장사항
    issue_types = issues.group_by { |i| i[:type] }
    
    if issue_types['high_empty_cells']
      recommendations << {
        priority: 'medium',
        action: "Remove or fill empty rows/columns to reduce file size"
      }
    end
    
    if issue_types['inconsistent_data_type']
      recommendations << {
        priority: 'high',
        action: "Standardize data types in mixed columns for better analysis"
      }
    end
    
    if issue_types['duplicate_data']
      recommendations << {
        priority: 'low',
        action: "Consider removing duplicate rows to improve data quality"
      }
    end
    
    if issue_types['inconsistent_date_format']
      recommendations << {
        priority: 'medium',
        action: "Use consistent date format throughout the spreadsheet"
      }
    end
    
    recommendations
  end
  
  def determine_severity(error_type)
    case error_type
    when /^#/, 'circular_reference', 'missing_sheet_reference'
      'error'
    when 'data_type_mismatch', 'risky_formula', 'out_of_bounds_reference'
      'warning'
    else
      'info'
    end
  end
  
  def get_error_description(error_type)
    descriptions = {
      '#REF!' => 'Invalid cell reference - cell or range doesn\'t exist',
      '#VALUE!' => 'Wrong data type - formula expects different type',
      '#NAME?' => 'Unrecognized formula name or reference',
      '#DIV/0!' => 'Division by zero error',
      '#NULL!' => 'Incorrect range operator',
      '#NUM!' => 'Invalid numeric value',
      '#N/A' => 'Value not available'
    }
    
    descriptions[error_type] || 'Unknown error'
  end
  
  def risky_formula?(formula)
    # 위험한 패턴 검사
    risky_patterns = [
      /INDIRECT/i,      # 동적 참조
      /OFFSET/i,        # 동적 범위
      /[A-Z]+:[A-Z]+/,  # 전체 열 참조
      /\d+:\d+/         # 전체 행 참조
    ]
    
    risky_patterns.any? { |pattern| formula =~ pattern }
  end
  
  def extract_sheet_references(formula)
    sheets = []
    
    # Sheet!Cell 패턴
    formula.scan(/([A-Za-z_][\w\s]*)?!/) do |match|
      sheets << match[0] if match[0]
    end
    
    # 'Sheet Name'!Cell 패턴
    formula.scan(/'([^']+)'!/) do |match|
      sheets << match[0]
    end
    
    sheets.uniq
  end
  
  def extract_cell_references(formula)
    references = []
    
    # 기본 셀 참조 패턴
    cell_pattern = /(?:[A-Za-z_\w]+!)?[$]?[A-Z]+[$]?\d+/
    formula.scan(cell_pattern) { |match| references << match }
    
    references.uniq
  end
  
  def out_of_bounds_reference?(formula, sheet)
    return false unless sheet['rows'] && sheet['columns']
    
    max_row = sheet['rows']
    max_col = sheet['columns']
    
    # 셀 참조 추출
    references = extract_cell_references(formula)
    
    references.any? do |ref|
      # 시트 참조 제거
      cell_ref = ref.split('!').last
      
      # 열과 행 분리
      if cell_ref =~ /([A-Z]+)(\d+)/
        col_letters = $1
        row_num = $2.to_i
        
        col_num = col_letters.chars.inject(0) { |sum, char| sum * 26 + (char.ord - 'A'.ord + 1) }
        
        row_num > max_row || col_num > max_col
      else
        false
      end
    end
  end
  
  def get_file_path(excel_file)
    if excel_file.file_url.start_with?('/')
      Rails.root.join('tmp', 'uploads', File.basename(excel_file.file_url))
    else
      ActiveStorage::Blob.service.path_for(excel_file.file_url)
    end
  end
end