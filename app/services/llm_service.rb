# frozen_string_literal: true

require "net/http"
require "json"

class LLMService
  class LLMError < StandardError; end

  MODELS = {
    gpt4: "gpt-4-turbo-preview",
    gpt35: "gpt-3.5-turbo",
    claude: "claude-3-opus-20240229"
  }.freeze

  DEFAULT_MODEL = :gpt4
  MAX_TOKENS = 4096
  TEMPERATURE = 0.7

  def initialize(model: DEFAULT_MODEL)
    @model = MODELS[model] || MODELS[DEFAULT_MODEL]
    @api_key = ENV["OPENAI_API_KEY"]
    @api_url = "https://api.openai.com/v1/chat/completions"
  end

  # Excel 파일 분석과 사용자 질문을 결합하여 처리
  def analyze_excel_with_context(excel_file, user_query, options = {})
    # Excel 데이터 추출 및 요약
    data_context = extract_excel_context(excel_file, options[:sample_size] || 100)

    # 프롬프트 구성
    messages = build_analysis_prompt(data_context, user_query)

    # LLM 호출
    response = call_llm(messages, options)

    # 응답 처리
    process_analysis_response(response, excel_file)
  end

  # 스트리밍 응답을 위한 메서드
  def analyze_excel_streaming(excel_file, user_query, options = {}, &block)
    data_context = extract_excel_context(excel_file, options[:sample_size] || 100)
    messages = build_analysis_prompt(data_context, user_query)

    stream_llm_response(messages, options, &block)
  end

  # 코드 생성 및 실행 제안
  def generate_analysis_code(excel_file, user_request)
    data_summary = create_data_summary(excel_file)

    messages = [
      {
        role: "system",
        content: SYSTEM_PROMPTS[:code_generator]
      },
      {
        role: "user",
        content: build_code_generation_prompt(data_summary, user_request)
      }
    ]

    response = call_llm(messages, { max_tokens: 2048 })
    extract_code_from_response(response)
  end

  # AI 상담 메시지 처리
  def process_consultation_message(chat_session, message, excel_context = nil)
    messages = build_consultation_messages(chat_session, excel_context)
    messages << { role: "user", content: message }

    response = call_llm(messages, { temperature: 0.8 })

    {
      content: response["choices"][0]["message"]["content"],
      suggestions: extract_suggestions(response),
      code_snippets: extract_code_snippets(response)
    }
  end

  private

  SYSTEM_PROMPTS = {
    excel_analyst: <<~PROMPT,
      You are an expert Excel analyst and data scientist. You help users understand their Excel data,#{' '}
      identify patterns, fix errors, and provide actionable insights. You can write Python code for#{' '}
      data analysis when needed. Always explain your reasoning and provide specific examples.
    PROMPT

    code_generator: <<~PROMPT,
      You are a Python data analysis expert. Generate clean, efficient Python code using pandas, numpy,#{' '}
      and other data science libraries. Always include error handling and comments. Focus on practical#{' '}
      solutions that can be executed in a Jupyter environment.
    PROMPT

    consultant: <<~PROMPT
      You are a friendly Excel consultant helping users solve their spreadsheet problems. Provide#{' '}
      clear, step-by-step guidance. When referencing the Excel file, be specific about sheet names,#{' '}
      cell ranges, and formulas. Suggest best practices and offer multiple solutions when appropriate.
    PROMPT
  }.freeze

  def extract_excel_context(excel_file, sample_size)
    analysis_result = excel_file.analysis_result || {}

    {
      file_info: {
        filename: excel_file.filename,
        size: excel_file.file_size,
        sheets: analysis_result.dig("file_analysis", "sheets") || []
      },
      summary: analysis_result.dig("file_analysis", "summary") || {},
      errors: analysis_result.dig("file_analysis", "errors") || [],
      sample_data: fetch_sample_data(excel_file, sample_size),
      formulas: analysis_result.dig("file_analysis", "formulas") || {}
    }
  end

  def fetch_sample_data(excel_file, sample_size)
    # Python 서비스를 통해 샘플 데이터 가져오기
    python_client = PythonServiceClient.new

    begin
      response = python_client.get_sample_data(excel_file.file_url, sample_size)
      response["sample_data"]
    rescue StandardError => e
      Rails.logger.error "Failed to fetch sample data: #{e.message}"
      {}
    end
  end

  def build_analysis_prompt(data_context, user_query)
    [
      {
        role: "system",
        content: SYSTEM_PROMPTS[:excel_analyst]
      },
      {
        role: "assistant",
        content: "I have access to the Excel file: #{data_context[:file_info][:filename]}. " \
                 "Here's what I know about it:\n" \
                 "#{format_file_context(data_context)}"
      },
      {
        role: "user",
        content: user_query
      }
    ]
  end

  def format_file_context(context)
    output = []

    # 파일 요약
    summary = context[:summary]
    output << "📊 File Summary:"
    output << "- Total Sheets: #{summary['total_sheets'] || 0}"
    output << "- Total Rows: #{summary['total_rows'] || 0}"
    output << "- Total Columns: #{summary['total_columns'] || 0}"
    output << "- Formulas: #{summary['total_formulas'] || 0}"

    # 오류 정보
    if context[:errors].any?
      output << "\n⚠️ Errors Found:"
      context[:errors].each do |error|
        output << "- #{error['error_type']}: #{error['count']} occurrences"
      end
    end

    # 샘플 데이터
    if context[:sample_data].present?
      output << "\n📋 Sample Data Available:"
      context[:sample_data].each do |sheet_name, data|
        output << "- Sheet '#{sheet_name}': #{data['rows']}x#{data['columns']}"
      end
    end

    output.join("\n")
  end

  def call_llm(messages, options = {})
    uri = URI(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"

    request.body = {
      model: @model,
      messages: messages,
      max_tokens: options[:max_tokens] || MAX_TOKENS,
      temperature: options[:temperature] || TEMPERATURE,
      stream: false
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      raise LLMError, "LLM API error: #{response.code} - #{response.body}"
    end
  end

  def stream_llm_response(messages, options = {})
    uri = URI(@api_url)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "text/event-stream"

      request.body = {
        model: @model,
        messages: messages,
        max_tokens: options[:max_tokens] || MAX_TOKENS,
        temperature: options[:temperature] || TEMPERATURE,
        stream: true
      }.to_json

      http.request(request) do |response|
        response.read_body do |chunk|
          yield chunk if block_given?
        end
      end
    end
  end

  def process_analysis_response(response, excel_file)
    content = response["choices"][0]["message"]["content"]

    {
      analysis: content,
      insights: extract_insights(content),
      recommendations: extract_recommendations(content),
      code_suggestions: extract_code_snippets(response),
      visualizations: extract_visualization_suggestions(content)
    }
  end

  def extract_insights(content)
    # 인사이트 추출 로직
    insights = []

    # 패턴 매칭으로 주요 발견사항 추출
    content.scan(/(?:insight|finding|observation|pattern):\s*(.+?)(?:\n|$)/i) do |match|
      insights << match[0].strip
    end

    insights
  end

  def extract_recommendations(content)
    recommendations = []

    content.scan(/(?:recommend|suggest|should|could):\s*(.+?)(?:\n|$)/i) do |match|
      recommendations << match[0].strip
    end

    recommendations
  end

  def extract_code_snippets(response)
    content = response["choices"][0]["message"]["content"]
    code_blocks = []

    # 코드 블록 추출 (```python ... ```)
    content.scan(/```python\n(.*?)```/m) do |match|
      code_blocks << {
        language: "python",
        code: match[0].strip
      }
    end

    code_blocks
  end

  def extract_visualization_suggestions(content)
    visualizations = []

    # 시각화 제안 추출
    viz_keywords = [ "chart", "graph", "plot", "visualization", "diagram" ]
    viz_keywords.each do |keyword|
      content.scan(/#{keyword}[^.]*\./i) do |match|
        visualizations << match.strip
      end
    end

    visualizations.uniq
  end

  def build_consultation_messages(chat_session, excel_context)
    messages = [
      {
        role: "system",
        content: SYSTEM_PROMPTS[:consultant]
      }
    ]

    # Excel 컨텍스트가 있으면 추가
    if excel_context
      messages << {
        role: "system",
        content: "User is working with Excel file: #{format_file_context(excel_context)}"
      }
    end

    # 이전 대화 내역 추가 (최근 10개만)
    recent_messages = chat_session.messages.order(created_at: :desc).limit(10).reverse
    recent_messages.each do |msg|
      messages << {
        role: msg.is_ai? ? "assistant" : "user",
        content: msg.content
      }
    end

    messages
  end

  def build_code_generation_prompt(data_summary, user_request)
    <<~PROMPT
      Excel File Summary:
      #{data_summary.to_json}

      User Request: #{user_request}

      Generate Python code to accomplish this task. Use pandas for data manipulation.
      Include proper error handling and comments explaining each step.
      If visualization is needed, use matplotlib or seaborn.
    PROMPT
  end

  def extract_code_from_response(response)
    content = response["choices"][0]["message"]["content"]

    # 코드 블록 추출
    code_match = content.match(/```python\n(.*?)```/m)
    code = code_match ? code_match[1].strip : ""

    # 설명 추출
    explanation = content.gsub(/```python.*?```/m, "").strip

    {
      code: code,
      explanation: explanation,
      dependencies: extract_dependencies(code)
    }
  end

  def extract_dependencies(code)
    dependencies = []

    # import 문 분석
    code.scan(/import\s+(\w+)/) do |match|
      dependencies << match[0]
    end

    code.scan(/from\s+(\w+)\s+import/) do |match|
      dependencies << match[0]
    end

    dependencies.uniq
  end

  def extract_suggestions(response)
    # AI 응답에서 구체적인 제안사항 추출
    content = response["choices"][0]["message"]["content"]
    suggestions = []

    # 번호가 매겨진 제안사항 찾기
    content.scan(/\d+\.\s*(.+?)(?:\n|$)/) do |match|
      suggestions << match[0].strip
    end

    suggestions
  end

  def create_data_summary(excel_file)
    {
      filename: excel_file.filename,
      sheets: excel_file.analysis_result.dig("file_analysis", "sheets") || [],
      total_rows: excel_file.analysis_result.dig("file_analysis", "summary", "total_rows") || 0,
      total_columns: excel_file.analysis_result.dig("file_analysis", "summary", "total_columns") || 0,
      has_errors: excel_file.errors_found > 0,
      error_types: excel_file.analysis_result.dig("file_analysis", "errors")&.map { |e| e["error_type"] } || []
    }
  end
end
