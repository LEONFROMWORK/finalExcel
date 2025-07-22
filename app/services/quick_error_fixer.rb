# frozen_string_literal: true

# Excel 오류를 빠르게 자동 수정하는 서비스
class QuickErrorFixer < Shared::BaseClasses::ApplicationService
  
  attr_reader :excel_file
  
  def initialize(excel_file)
    @excel_file = excel_file
  end
  
  def fix_error(error_type, location)
    case error_type
    when '#DIV/0!'
      fix_div_zero_error(location)
    when '#VALUE!'
      fix_value_error(location)
    when '#REF!'
      fix_ref_error(location)
    when '#N/A'
      fix_na_error(location)
    when 'data_type_mismatch'
      fix_data_type_mismatch(location)
    when 'missing_headers'
      fix_missing_headers(location)
    else
      {
        success: false,
        message: "Auto-fix not available for #{error_type}",
        manual_steps: get_manual_fix_steps(error_type)
      }
    end
  end
  
  private
  
  def fix_div_zero_error(location)
    # #DIV/0! 오류 자동 수정
    original_formula = get_formula_at_location(location)
    
    if original_formula
      # IFERROR로 감싸기
      fixed_formula = "=IFERROR(#{original_formula.sub('=', '')}, 0)"
      
      {
        success: true,
        original: original_formula,
        fixed_value: fixed_formula,
        message: "Wrapped formula with IFERROR to handle division by zero"
      }
    else
      {
        success: false,
        message: "Could not retrieve formula at #{location}"
      }
    end
  end
  
  def fix_value_error(location)
    # #VALUE! 오류 자동 수정
    original_formula = get_formula_at_location(location)
    
    if original_formula
      # 숫자 변환 시도
      if original_formula.include?('*') || original_formula.include?('+') || 
         original_formula.include?('-') || original_formula.include?('/')
        
        # VALUE 함수로 텍스트를 숫자로 변환
        fixed_formula = original_formula.gsub(/([A-Z]+\d+)/) do |cell_ref|
          "VALUE(#{cell_ref})"
        end
        
        {
          success: true,
          original: original_formula,
          fixed_value: fixed_formula,
          message: "Wrapped cell references with VALUE() to convert text to numbers"
        }
      else
        # IFERROR로 감싸기
        fixed_formula = "=IFERROR(#{original_formula.sub('=', '')}, \"\")"
        
        {
          success: true,
          original: original_formula,
          fixed_value: fixed_formula,
          message: "Wrapped formula with IFERROR to handle value errors"
        }
      end
    else
      {
        success: false,
        message: "Could not retrieve formula at #{location}"
      }
    end
  end
  
  def fix_ref_error(location)
    # #REF! 오류는 자동 수정이 어려움
    {
      success: false,
      message: "#REF! errors require manual intervention",
      manual_steps: [
        "1. Check if referenced cells/sheets were deleted",
        "2. Update formula to reference existing cells",
        "3. Restore deleted sheets if needed",
        "4. Use IFERROR to handle missing references gracefully"
      ]
    }
  end
  
  def fix_na_error(location)
    # #N/A 오류 자동 수정
    original_formula = get_formula_at_location(location)
    
    if original_formula
      if original_formula.include?('VLOOKUP') || original_formula.include?('HLOOKUP')
        # IFNA로 감싸기
        fixed_formula = "=IFNA(#{original_formula.sub('=', '')}, \"Not Found\")"
        
        {
          success: true,
          original: original_formula,
          fixed_value: fixed_formula,
          message: "Wrapped lookup formula with IFNA to handle missing values"
        }
      else
        # IFERROR로 감싸기
        fixed_formula = "=IFERROR(#{original_formula.sub('=', '')}, \"\")"
        
        {
          success: true,
          original: original_formula,
          fixed_value: fixed_formula,
          message: "Wrapped formula with IFERROR to handle N/A errors"
        }
      end
    else
      {
        success: false,
        message: "Could not retrieve formula at #{location}"
      }
    end
  end
  
  def fix_data_type_mismatch(location)
    # 데이터 타입 불일치 수정
    column_info = parse_column_location(location)
    
    if column_info
      {
        success: true,
        message: "Data type standardization required",
        manual_steps: [
          "1. Select column #{column_info[:column]}",
          "2. Use Data > Text to Columns to convert data types",
          "3. Or use =VALUE() for numeric conversion",
          "4. Use =TEXT() for text conversion",
          "5. Apply consistent formatting to the column"
        ],
        suggested_formula: "=VALUE(#{column_info[:column]}2)"
      }
    else
      {
        success: false,
        message: "Invalid location format"
      }
    end
  end
  
  def fix_missing_headers(location)
    # 헤더 누락 수정
    {
      success: true,
      message: "Headers need to be added",
      manual_steps: [
        "1. Insert a new row at the top if needed",
        "2. Add descriptive column names",
        "3. Format headers with bold text",
        "4. Consider freezing the header row"
      ],
      suggested_headers: generate_default_headers
    }
  end
  
  def get_formula_at_location(location)
    # 위치에서 수식 가져오기
    # 실제 구현에서는 Python 서비스와 통신
    analysis = @excel_file.analysis_result
    
    if analysis && analysis['sheets']
      analysis['sheets'].each do |sheet|
        if sheet['formulas']
          formula_info = sheet['formulas'].find { |f| f['cell'] == location }
          return formula_info['formula'] if formula_info
        end
      end
    end
    
    nil
  end
  
  def parse_column_location(location)
    # "Column A" -> { column: 'A' }
    if location =~ /Column\s+([A-Z]+)/i
      { column: $1 }
    else
      nil
    end
  end
  
  def generate_default_headers
    # 기본 헤더 생성
    analysis = @excel_file.analysis_result
    
    if analysis && analysis['sheets'] && analysis['sheets'].first
      num_columns = analysis['sheets'].first['columns'] || 10
      
      (1..num_columns).map { |i| "Column #{('A'.ord + i - 1).chr}" }
    else
      %w[Column_A Column_B Column_C Column_D Column_E]
    end
  end
  
  def get_manual_fix_steps(error_type)
    manual_fixes = {
      'circular_reference' => [
        "1. Use Formula Auditing > Trace Precedents",
        "2. Identify the circular reference chain",
        "3. Break the chain by removing self-references",
        "4. Consider using iterative calculation if needed"
      ],
      'volatile_function' => [
        "1. Replace NOW() with a static timestamp if possible",
        "2. Replace RAND() with static random values",
        "3. Use INDIRECT sparingly",
        "4. Consider calculation performance impact"
      ],
      'full_column_reference' => [
        "1. Limit references to actual data range",
        "2. Use dynamic named ranges",
        "3. Replace A:A with A1:A1000 (actual range)",
        "4. Consider using Tables for dynamic ranges"
      ]
    }
    
    manual_fixes[error_type] || ["Please consult Excel documentation for #{error_type}"]
  end
end