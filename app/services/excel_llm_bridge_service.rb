# frozen_string_literal: true

# Excel 데이터를 LLM이 이해하고 처리할 수 있는 형식으로 변환하는 브릿지 서비스
class ExcelLLMBridgeService
  MAX_CELLS_FOR_CONTEXT = 1000  # LLM 컨텍스트 제한을 위한 최대 셀 수
  MAX_PREVIEW_ROWS = 20         # 미리보기 최대 행 수
  
  def initialize(excel_file)
    @excel_file = excel_file
    @python_client = PythonServiceClient.new
  end
  
  # Excel 파일을 LLM이 이해할 수 있는 구조화된 텍스트로 변환
  def serialize_for_llm(options = {})
    focus_area = options[:focus_area]  # 특정 시트나 범위에 집중
    include_formulas = options[:include_formulas] != false
    include_formatting = options[:include_formatting] || false
    
    data = fetch_excel_data(focus_area)
    
    {
      summary: create_summary(data),
      structure: serialize_structure(data),
      sample_data: serialize_sample_data(data, include_formulas),
      formulas: include_formulas ? serialize_formulas(data) : nil,
      formatting: include_formatting ? serialize_formatting(data) : nil,
      issues: serialize_issues(data),
      metadata: serialize_metadata
    }
  end
  
  # 특정 문제에 대한 컨텍스트 생성
  def create_problem_context(problem_description, options = {})
    # 문제와 관련된 데이터만 추출
    relevant_data = extract_relevant_data(problem_description)
    
    context = {
      problem: problem_description,
      file_overview: create_summary(relevant_data),
      related_sheets: find_related_sheets(problem_description, relevant_data),
      relevant_formulas: find_relevant_formulas(problem_description, relevant_data),
      data_sample: create_focused_sample(relevant_data, problem_description),
      detected_patterns: detect_patterns(relevant_data)
    }
    
    # 토큰 제한을 고려한 압축
    compress_context(context, options[:max_tokens] || 4000)
  end
  
  # LLM 응답을 Excel 작업으로 변환
  def parse_llm_solution(llm_response, context = {})
    solution = {
      modifications: [],
      formulas: [],
      formatting: [],
      validations: [],
      explanations: []
    }
    
    # 코드 블록 추출
    code_blocks = extract_code_blocks(llm_response)
    
    code_blocks.each do |block|
      case block[:language]
      when 'excel', 'formula'
        solution[:formulas] += parse_excel_formulas(block[:code])
      when 'python'
        solution[:modifications] += parse_python_modifications(block[:code], context)
      when 'json'
        solution[:modifications] += parse_json_modifications(block[:code])
      end
    end
    
    # 텍스트 설명에서 작업 추출
    solution[:explanations] = extract_explanations(llm_response)
    
    # 실행 가능한 작업으로 변환
    convert_to_executable_actions(solution)
  end
  
  # 이미지와 Excel 데이터 연관 분석
  def correlate_with_image(image_analysis_result)
    excel_data = fetch_excel_data
    
    correlation = {
      matched_data: [],
      discrepancies: [],
      suggestions: []
    }
    
    # 이미지에서 추출된 표와 Excel 시트 매칭
    if image_analysis_result['tables']
      image_analysis_result['tables'].each do |img_table|
        matched_sheet = find_matching_sheet(img_table, excel_data)
        
        if matched_sheet
          correlation[:matched_data] << {
            image_table: img_table,
            excel_sheet: matched_sheet[:name],
            similarity_score: matched_sheet[:score],
            differences: compare_data(img_table, matched_sheet[:data])
          }
        else
          correlation[:discrepancies] << {
            image_table: img_table,
            suggestion: suggest_sheet_creation(img_table)
          }
        end
      end
    end
    
    # 차트 데이터 연관성 분석
    if image_analysis_result['charts']
      correlation[:chart_analysis] = analyze_chart_correlation(
        image_analysis_result['charts'],
        excel_data
      )
    end
    
    correlation[:suggestions] = generate_correlation_suggestions(correlation)
    correlation
  end
  
  private
  
  def fetch_excel_data(focus_area = nil)
    # Python 서비스에서 상세 데이터 가져오기
    file_path = get_file_path(@excel_file)
    
    @python_client.get_detailed_analysis(file_path, {
      focus_area: focus_area,
      include_values: true,
      include_formulas: true,
      include_formatting: true
    })
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Excel data: #{e.message}"
    @excel_file.analysis_result || {}
  end
  
  def create_summary(data)
    summary = []
    
    summary << "📊 Excel File Overview:"
    summary << "- Filename: #{@excel_file.filename}"
    summary << "- Total Sheets: #{data['sheets']&.size || 0}"
    summary << "- File Size: #{format_file_size(@excel_file.file_size)}"
    
    if data['summary']
      summary << "- Total Rows: #{data['summary']['total_rows']}"
      summary << "- Total Columns: #{data['summary']['total_columns']}"
      summary << "- Formulas: #{data['summary']['total_formulas']}"
      summary << "- Charts: #{data['summary']['total_charts'] || 0}"
    end
    
    if data['errors']&.any?
      summary << "\n⚠️ Issues Found: #{data['errors'].size} errors"
    end
    
    summary.join("\n")
  end
  
  def serialize_structure(data)
    return {} unless data['sheets']
    
    structure = {}
    
    data['sheets'].each do |sheet|
      structure[sheet['name']] = {
        dimensions: "#{sheet['rows']}x#{sheet['columns']}",
        headers: sheet['headers'] || detect_headers(sheet),
        data_types: sheet['data_types'] || {},
        has_formulas: sheet['formula_count'] > 0,
        has_charts: sheet['charts']&.any? || false,
        named_ranges: sheet['named_ranges'] || []
      }
    end
    
    structure
  end
  
  def serialize_sample_data(data, include_formulas)
    samples = {}
    
    data['sheets']&.each do |sheet|
      next unless sheet['sample_data']
      
      samples[sheet['name']] = {
        preview: format_data_preview(sheet['sample_data'], MAX_PREVIEW_ROWS),
        column_stats: calculate_column_stats(sheet['sample_data']),
        formulas: include_formulas ? extract_sample_formulas(sheet) : nil
      }
    end
    
    samples
  end
  
  def serialize_formulas(data)
    formulas = {
      by_type: {},
      complex_formulas: [],
      dependencies: {}
    }
    
    data['sheets']&.each do |sheet|
      next unless sheet['formulas']
      
      sheet['formulas'].each do |formula_info|
        # 수식 타입별 분류
        formula_type = detect_formula_type(formula_info['formula'])
        formulas[:by_type][formula_type] ||= []
        formulas[:by_type][formula_type] << {
          sheet: sheet['name'],
          cell: formula_info['cell'],
          formula: formula_info['formula']
        }
        
        # 복잡한 수식 식별
        if is_complex_formula?(formula_info['formula'])
          formulas[:complex_formulas] << formula_info.merge(sheet: sheet['name'])
        end
        
        # 의존성 분석
        deps = extract_formula_dependencies(formula_info['formula'])
        if deps.any?
          formulas[:dependencies][formula_info['cell']] = deps
        end
      end
    end
    
    formulas
  end
  
  def extract_relevant_data(problem_description)
    keywords = extract_keywords(problem_description)
    
    data = fetch_excel_data
    relevant = {
      'sheets' => [],
      'summary' => data['summary'],
      'errors' => []
    }
    
    # 키워드와 매칭되는 시트 찾기
    data['sheets']&.each do |sheet|
      relevance_score = calculate_relevance(sheet, keywords)
      if relevance_score > 0.3
        relevant['sheets'] << sheet.merge('relevance_score' => relevance_score)
      end
    end
    
    # 관련 오류 찾기
    data['errors']&.each do |error|
      if keywords.any? { |kw| error['description']&.downcase&.include?(kw.downcase) }
        relevant['errors'] << error
      end
    end
    
    relevant
  end
  
  def find_matching_sheet(img_table, excel_data)
    best_match = nil
    best_score = 0
    
    excel_data['sheets']&.each do |sheet|
      score = calculate_table_similarity(img_table, sheet)
      
      if score > best_score && score > 0.7  # 70% 유사도 임계값
        best_match = {
          name: sheet['name'],
          data: sheet,
          score: score
        }
        best_score = score
      end
    end
    
    best_match
  end
  
  def calculate_table_similarity(img_table, sheet)
    score = 0.0
    factors = 0
    
    # 크기 비교
    if img_table['rows'] && sheet['rows']
      size_diff = (img_table['rows'] - sheet['rows']).abs.to_f / [img_table['rows'], sheet['rows']].max
      score += (1 - size_diff) * 0.3
      factors += 0.3
    end
    
    # 헤더 비교
    if img_table['headers'] && sheet['headers']
      header_similarity = calculate_text_similarity(img_table['headers'], sheet['headers'])
      score += header_similarity * 0.5
      factors += 0.5
    end
    
    # 데이터 샘플 비교
    if img_table['sample_data'] && sheet['sample_data']
      data_similarity = calculate_data_similarity(img_table['sample_data'], sheet['sample_data'])
      score += data_similarity * 0.2
      factors += 0.2
    end
    
    factors > 0 ? score / factors : 0
  end
  
  def compare_data(img_table, excel_sheet_data)
    differences = []
    
    # 헤더 차이
    if img_table['headers'] && excel_sheet_data['headers']
      img_headers = img_table['headers']
      excel_headers = excel_sheet_data['headers']
      
      missing_in_excel = img_headers - excel_headers
      missing_in_image = excel_headers - img_headers
      
      if missing_in_excel.any?
        differences << {
          type: 'missing_headers',
          location: 'excel',
          values: missing_in_excel
        }
      end
      
      if missing_in_image.any?
        differences << {
          type: 'missing_headers',
          location: 'image',
          values: missing_in_image
        }
      end
    end
    
    # 데이터 값 차이
    if img_table['sample_data'] && excel_sheet_data['sample_data']
      value_differences = find_value_differences(
        img_table['sample_data'],
        excel_sheet_data['sample_data']
      )
      differences.concat(value_differences)
    end
    
    differences
  end
  
  def suggest_sheet_creation(img_table)
    {
      action: 'create_sheet',
      sheet_name: suggest_sheet_name(img_table),
      structure: {
        headers: img_table['headers'],
        data_types: infer_data_types(img_table['sample_data']),
        initial_data: img_table['sample_data']
      }
    }
  end
  
  def generate_correlation_suggestions(correlation)
    suggestions = []
    
    # 매칭된 데이터에 대한 제안
    correlation[:matched_data]&.each do |match|
      if match[:differences].any?
        suggestions << {
          type: 'sync_data',
          priority: 'high',
          description: "Sync differences between image and #{match[:excel_sheet]}",
          actions: generate_sync_actions(match[:differences])
        }
      end
    end
    
    # 불일치 데이터에 대한 제안
    correlation[:discrepancies]&.each do |discrepancy|
      suggestions << {
        type: 'create_missing',
        priority: 'medium',
        description: "Create new sheet from image data",
        action: discrepancy[:suggestion]
      }
    end
    
    suggestions
  end
  
  def convert_to_executable_actions(solution)
    actions = []
    
    # 수식 추가/수정
    solution[:formulas].each do |formula|
      actions << {
        type: 'update_cell',
        cell: formula[:cell],
        value: formula[:formula],
        sheet: formula[:sheet]
      }
    end
    
    # 데이터 수정
    solution[:modifications].each do |mod|
      actions << normalize_modification(mod)
    end
    
    # 검증 가능한 형식으로 변환
    actions.map { |action| validate_and_enhance_action(action) }
  end
  
  def compress_context(context, max_tokens)
    estimated_tokens = estimate_tokens(context.to_json)
    
    if estimated_tokens > max_tokens
      # 토큰 초과 시 압축 전략
      context[:data_sample] = reduce_sample_size(context[:data_sample])
      context[:relevant_formulas] = context[:relevant_formulas]&.first(20)
      context[:related_sheets] = context[:related_sheets]&.first(3)
    end
    
    context
  end
  
  def extract_keywords(text)
    # 중요 키워드 추출
    keywords = text.downcase.scan(/\b\w+\b/)
                   .reject { |w| w.length < 3 }
                   .reject { |w| STOP_WORDS.include?(w) }
    
    # Excel 관련 특수 키워드 추가
    excel_keywords = []
    excel_keywords << 'sum' if text.match?(/합계|sum|total/i)
    excel_keywords << 'vlookup' if text.match?(/vlookup|찾기|검색/i)
    excel_keywords << 'pivot' if text.match?(/pivot|피벗/i)
    
    (keywords + excel_keywords).uniq
  end
  
  def calculate_relevance(sheet, keywords)
    score = 0.0
    
    # 시트 이름 매칭
    keywords.each do |keyword|
      score += 0.3 if sheet['name'].downcase.include?(keyword)
    end
    
    # 헤더 매칭
    if sheet['headers']
      matching_headers = sheet['headers'].count { |h| 
        keywords.any? { |k| h.downcase.include?(k) }
      }
      score += (matching_headers.to_f / sheet['headers'].size) * 0.4
    end
    
    # 데이터 내용 매칭 (샘플)
    if sheet['sample_data']
      # 샘플 데이터에서 키워드 출현 빈도
      keyword_frequency = calculate_keyword_frequency(sheet['sample_data'], keywords)
      score += [keyword_frequency * 0.3, 0.3].min
    end
    
    [score, 1.0].min
  end
  
  def format_file_size(bytes)
    return '0 Bytes' if bytes == 0
    
    k = 1024
    sizes = ['Bytes', 'KB', 'MB', 'GB']
    i = (Math.log(bytes) / Math.log(k)).floor
    
    "#{(bytes.to_f / (k**i)).round(2)} #{sizes[i]}"
  end
  
  def get_file_path(excel_file)
    if excel_file.file_url.start_with?('/')
      Rails.root.join('tmp', 'uploads', File.basename(excel_file.file_url))
    else
      ActiveStorage::Blob.service.path_for(excel_file.file_url)
    end
  end
  
  def estimate_tokens(text)
    # 간단한 토큰 추정 (실제로는 tiktoken 사용)
    text.split(/\s+/).size * 1.3
  end
  
  STOP_WORDS = %w[the is at which on a an as are was were been be have has had do does did will would could should may might must shall can].freeze
  
  def detect_formula_type(formula)
    case formula
    when /^=SUM\(/i then 'aggregation'
    when /^=AVERAGE|MEDIAN|MODE/i then 'statistical'
    when /^=VLOOKUP|HLOOKUP|INDEX|MATCH/i then 'lookup'
    when /^=IF|IFS|SWITCH/i then 'conditional'
    when /^=COUNT|COUNTA|COUNTIF/i then 'counting'
    else 'other'
    end
  end
  
  def is_complex_formula?(formula)
    # 중첩 함수, 배열 수식, 긴 수식 등
    formula.count('(') > 3 || formula.length > 100 || formula.include?('ARRAY')
  end
  
  def detect_column_types(values)
    types = values.map { |v| detect_value_type(v) }
    
    # 가장 많은 타입 반환
    type_counts = types.tally
    primary_type = type_counts.max_by { |_, count| count }&.first || 'text'
    
    {
      primary: primary_type,
      distribution: type_counts,
      mixed: type_counts.size > 1
    }
  end
  
  def detect_value_type(value)
    return 'empty' if value.nil? || value.to_s.strip.empty?
    
    # 숫자 검사
    if value.is_a?(Numeric) || value.to_s =~ /^-?\d+\.?\d*$/
      'number'
    # 날짜 검사
    elsif value.is_a?(Date) || value.is_a?(Time) || value.to_s =~ /^\d{4}-\d{2}-\d{2}/
      'date'
    # 수식 검사
    elsif value.to_s.start_with?('=')
      'formula'
    # 불린 검사
    elsif %w[true false TRUE FALSE].include?(value.to_s)
      'boolean'
    else
      'text'
    end
  end
  
  def likely_headers?(first_row, data_rows)
    return false if first_row.nil? || data_rows.empty?
    
    # 첫 번째 행이 텍스트이고 나머지 행과 다른 타입인지 확인
    first_row_types = first_row.map { |v| detect_value_type(v) }
    
    # 모든 값이 텍스트인지 확인
    all_text = first_row_types.all? { |t| t == 'text' }
    
    # 데이터 행의 타입과 비교
    data_row_types = data_rows.first(5).flat_map { |row| 
      row.map { |v| detect_value_type(v) } 
    }.tally
    
    # 첫 행이 대부분 텍스트이고 데이터 행은 혼합 타입이면 헤더일 가능성 높음
    all_text && data_row_types.keys.size > 1
  end
  
  def extract_operation_type(code)
    case code
    when /pivot_table/i then 'pivot'
    when /groupby/i then 'group'
    when /merge/i then 'merge'
    when /concat/i then 'concatenate'
    when /filter/i then 'filter'
    when /sort/i then 'sort'
    else 'transform'
    end
  end
  
  def normalize_json_modification(mod)
    {
      type: mod['type'] || 'update',
      cell: mod['cell'] || mod['address'],
      value: mod['value'],
      sheet: mod['sheet'] || 'Sheet1',
      description: mod['description']
    }
  end
  
  def calculate_row_similarity(row1, row2)
    return 0.0 if row1.nil? || row2.nil?
    
    matches = 0
    comparisons = 0
    
    [row1.size, row2.size].min.times do |i|
      comparisons += 1
      if normalize_value(row1[i]) == normalize_value(row2[i])
        matches += 1
      end
    end
    
    comparisons > 0 ? matches.to_f / comparisons : 0.0
  end
  
  def normalize_value(value)
    value.to_s.downcase.strip.gsub(/\s+/, ' ')
  end
  
  def normalize_cell_reference(cell_ref)
    # A1 -> A1, sheet1!A1 -> Sheet1!A1, etc.
    cell_ref.to_s.upcase.strip
  end
  
  def validate_action_executable(action)
    case action[:type]
    when 'update_cell'
      !action[:cell].nil? && !action[:value].nil?
    when 'insert_row', 'insert_column', 'delete_row', 'delete_column'
      !action[:position].nil?
    else
      true
    end
  end
  
  def analyze_chart_correlation(charts, excel_data)
    correlations = []
    
    charts.each do |chart|
      # 차트 데이터와 Excel 데이터 비교
      if chart['data_points']
        matching_data = find_matching_data_series(chart['data_points'], excel_data)
        
        correlations << {
          chart_type: chart['type'],
          chart_title: chart['title'],
          matched_sheets: matching_data,
          confidence: calculate_chart_confidence(matching_data)
        }
      end
    end
    
    correlations
  end
  
  def find_matching_data_series(data_points, excel_data)
    matches = []
    
    excel_data['sheets']&.each do |sheet|
      if sheet['sample_data']
        # 데이터 시리즈 매칭 로직
        similarity = calculate_series_similarity(data_points, sheet['sample_data'])
        
        if similarity > 0.5
          matches << {
            sheet: sheet['name'],
            similarity: similarity,
            data_range: suggest_data_range(sheet)
          }
        end
      end
    end
    
    matches
  end
  
  def calculate_series_similarity(series1, series2)
    # 간단한 시리즈 유사도 계산
    0.7  # 임시 구현
  end
  
  def calculate_chart_confidence(matches)
    return 0.0 if matches.empty?
    
    # 최고 매칭 점수 반환
    matches.map { |m| m[:similarity] }.max
  end
  
  def suggest_data_range(sheet)
    # 데이터 범위 추천
    rows = sheet['rows'] || 0
    cols = sheet['columns'] || 0
    
    "A1:#{('A'.ord + cols - 1).chr}#{rows}"
  end
  
  def calculate_keyword_frequency(data, keywords)
    return 0.0 unless data && keywords.any?
    
    total_cells = 0
    keyword_matches = 0
    
    data.each do |row|
      row.each do |cell|
        cell_text = cell.to_s.downcase
        total_cells += 1
        
        if keywords.any? { |kw| cell_text.include?(kw.downcase) }
          keyword_matches += 1
        end
      end
    end
    
    total_cells > 0 ? keyword_matches.to_f / total_cells : 0.0
  end
end