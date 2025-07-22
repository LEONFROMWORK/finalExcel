# frozen_string_literal: true

require "net/http"
require "json"

class OpenRouterLLMService
  class LLMError < StandardError; end

  # OpenRouter에서 사용 가능한 모델들
  MODELS = {
    gpt4: "openai/gpt-4-turbo-preview",
    gpt35: "openai/gpt-3.5-turbo",
    claude_opus: "anthropic/claude-3-opus",
    claude_sonnet: "anthropic/claude-3-sonnet",
    claude_haiku: "anthropic/claude-3-haiku",
    gemini_pro: "google/gemini-pro",
    mixtral: "mistralai/mixtral-8x7b-instruct",
    llama3: "meta-llama/llama-3-70b-instruct"
  }.freeze

  DEFAULT_MODEL = :claude_opus  # Claude Opus가 Excel 분석에 뛰어남
  MAX_TOKENS = 4096
  TEMPERATURE = 0.7

  def initialize(model: DEFAULT_MODEL)
    @model = MODELS[model] || MODELS[DEFAULT_MODEL]
    @api_key = ENV["OPENROUTER_API_KEY"]
    @api_url = "https://openrouter.ai/api/v1/chat/completions"
    @site_url = ENV["APP_URL"] || "http://localhost:3000"
    @site_name = "Excel Unified"
  end

  # Excel 파일 분석과 사용자 질문을 결합하여 처리
  def analyze_excel_with_context(excel_file, user_query, options = {})
    # 모델 선택 (복잡한 분석은 Claude Opus, 간단한 작업은 Haiku)
    model = determine_best_model(user_query, excel_file)

    # Excel 데이터 추출 및 요약
    data_context = extract_excel_context(excel_file, options[:sample_size] || 100)

    # 프롬프트 구성
    messages = build_analysis_prompt(data_context, user_query)

    # LLM 호출
    response = call_openrouter(messages, { model: model }.merge(options))

    # 응답 처리
    process_analysis_response(response, excel_file)
  end

  # 스트리밍 응답을 위한 메서드
  def analyze_excel_streaming(excel_file, user_query, options = {}, &block)
    data_context = extract_excel_context(excel_file, options[:sample_size] || 100)
    messages = build_analysis_prompt(data_context, user_query)

    stream_openrouter_response(messages, options, &block)
  end

  # 코드 생성 및 실행 제안 (Code Interpreter 스타일)
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

    # 코드 생성은 Claude가 뛰어남
    response = call_openrouter(messages, {
      model: MODELS[:claude_opus],
      max_tokens: 2048
    })

    extract_code_from_response(response)
  end

  # AI 상담 메시지 처리
  def process_consultation_message(chat_session, message, excel_context = nil)
    messages = build_consultation_messages(chat_session, excel_context)
    messages << { role: "user", content: message }

    # 대화형 상담은 Claude Sonnet이 비용 효율적
    response = call_openrouter(messages, {
      model: MODELS[:claude_sonnet],
      temperature: 0.8
    })

    {
      content: response["choices"][0]["message"]["content"],
      model_used: response["model"],
      suggestions: extract_suggestions(response),
      code_snippets: extract_code_snippets(response),
      usage: {
        prompt_tokens: response["usage"]["prompt_tokens"],
        completion_tokens: response["usage"]["completion_tokens"],
        total_cost: calculate_cost(response)
      }
    }
  end

  private

  SYSTEM_PROMPTS = {
    excel_analyst: <<~PROMPT,
      You are an expert Excel analyst and data scientist. You help users understand their Excel data,#{' '}
      identify patterns, fix errors, and provide actionable insights. You can write Python code for#{' '}
      data analysis when needed. Always explain your reasoning and provide specific examples.

      When analyzing Excel files:
      1. First understand the data structure and quality
      2. Identify any data issues or errors
      3. Provide specific, actionable recommendations
      4. If needed, generate Python code that can be executed to solve the problem
      5. Explain results in business terms, not just technical terms
    PROMPT

    code_generator: <<~PROMPT,
      You are a Python data analysis expert specializing in Excel file processing. Generate clean,#{' '}
      efficient Python code using pandas, openpyxl, numpy, and other data science libraries.#{' '}

      Requirements:
      1. Always include proper error handling
      2. Add detailed comments explaining each step
      3. Use type hints where appropriate
      4. Optimize for large Excel files (chunking, memory efficiency)
      5. Include data validation steps
      6. Generate visualizations when it helps understand the data

      Format your response with:
      - Brief explanation of the approach
      - Complete Python code in a single code block
      - Expected output description
      - Any limitations or assumptions
    PROMPT

    consultant: <<~PROMPT
      You are a friendly Excel consultant helping users solve their spreadsheet problems. Provide#{' '}
      clear, step-by-step guidance. When referencing the Excel file, be specific about sheet names,#{' '}
      cell ranges, and formulas. Suggest best practices and offer multiple solutions when appropriate.

      Guidelines:
      1. Be conversational but professional
      2. Ask clarifying questions when needed
      3. Provide examples with actual Excel formulas
      4. Suggest both quick fixes and long-term improvements
      5. Consider the user's skill level and adjust explanations accordingly
    PROMPT
  }.freeze

  def determine_best_model(query, excel_file)
    # 간단한 휴리스틱으로 최적 모델 선택
    query_lower = query.downcase
    file_size = excel_file.file_size

    # 복잡한 분석이나 코드 생성이 필요한 경우
    if query_lower.match?(/code|python|script|analyze|pattern|trend|forecast/)
      MODELS[:claude_opus]
    # 대용량 파일이나 성능이 중요한 경우
    elsif file_size > 50.megabytes
      MODELS[:claude_haiku]
    # 일반적인 상담이나 질문
    else
      MODELS[:claude_sonnet]
    end
  end

  def extract_excel_context(excel_file, sample_size)
    analysis_result = excel_file.analysis_result || {}

    context = {
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

    # 대용량 컨텍스트는 요약
    if calculate_context_size(context) > 10000
      summarize_context(context)
    else
      context
    end
  end

  def call_openrouter(messages, options = {})
    uri = URI(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request["HTTP-Referer"] = @site_url
    request["X-Title"] = @site_name

    request.body = {
      model: options[:model] || @model,
      messages: messages,
      max_tokens: options[:max_tokens] || MAX_TOKENS,
      temperature: options[:temperature] || TEMPERATURE,
      stream: false,
      # OpenRouter 특정 옵션
      transforms: [ "middle-out" ],  # 자동 컨텍스트 압축
      route: "fallback"  # 모델 사용 불가시 대체 모델 사용
    }.to_json

    response = http.request(request)

    if response.code == "200"
      result = JSON.parse(response.body)
      log_usage(result)
      result
    else
      error_body = JSON.parse(response.body) rescue response.body
      raise LLMError, "OpenRouter API error: #{response.code} - #{error_body}"
    end
  end

  def stream_openrouter_response(messages, options = {})
    uri = URI(@api_url)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "text/event-stream"
      request["HTTP-Referer"] = @site_url
      request["X-Title"] = @site_name

      request.body = {
        model: options[:model] || @model,
        messages: messages,
        max_tokens: options[:max_tokens] || MAX_TOKENS,
        temperature: options[:temperature] || TEMPERATURE,
        stream: true,
        transforms: [ "middle-out" ]
      }.to_json

      http.request(request) do |response|
        response.read_body do |chunk|
          # SSE 파싱
          chunk.split("\n").each do |line|
            if line.start_with?("data: ")
              data = line[6..]
              next if data == "[DONE]"

              begin
                json = JSON.parse(data)
                yield json if block_given?
              rescue JSON::ParserError
                # 무시
              end
            end
          end
        end
      end
    end
  end

  def calculate_cost(response)
    # OpenRouter는 응답에 비용 정보를 포함
    response.dig("usage", "total_cost") || 0
  end

  def log_usage(response)
    # 사용량 로깅
    Rails.logger.info "OpenRouter Usage: Model=#{response['model']}, " \
                      "Tokens=#{response.dig('usage', 'total_tokens')}, " \
                      "Cost=$#{response.dig('usage', 'total_cost')}"
  end

  def calculate_context_size(context)
    # 대략적인 토큰 수 계산 (한글은 더 많은 토큰 사용)
    context.to_json.size / 3
  end

  def summarize_context(context)
    # 큰 컨텍스트를 요약
    {
      file_info: context[:file_info],
      summary: context[:summary],
      errors: context[:errors].first(10),  # 상위 10개 오류만
      sample_data: limit_sample_data(context[:sample_data]),
      formulas: context[:formulas]
    }
  end

  def limit_sample_data(sample_data)
    # 각 시트당 최대 10행만 포함
    limited = {}
    sample_data.each do |sheet, data|
      limited[sheet] = {
        "rows" => [ data["rows"], 10 ].min,
        "columns" => data["columns"],
        "preview" => data["preview"]&.first(10)
      }
    end
    limited
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
        output << "- #{error['error_type']}: #{error['count']} occurrences in #{error['locations']&.join(', ')}"
      end
    end

    # 샘플 데이터
    if context[:sample_data].present?
      output << "\n📋 Sample Data Available:"
      context[:sample_data].each do |sheet_name, data|
        output << "- Sheet '#{sheet_name}': #{data['rows']}x#{data['columns']}"
        if data["preview"]
          output << "  Preview: #{data['preview'].to_json}"
        end
      end
    end

    output.join("\n")
  end

  def process_analysis_response(response, excel_file)
    content = response["choices"][0]["message"]["content"]

    {
      analysis: content,
      model_used: response["model"],
      insights: extract_insights(content),
      recommendations: extract_recommendations(content),
      code_suggestions: extract_code_snippets(response),
      visualizations: extract_visualization_suggestions(content),
      usage: {
        tokens: response.dig("usage", "total_tokens"),
        cost: response.dig("usage", "total_cost")
      }
    }
  end

  def extract_insights(content)
    insights = []

    # 다양한 패턴으로 인사이트 추출
    patterns = [
      /(?:insight|finding|observation|pattern|discovered|found):\s*(.+?)(?:\n|$)/i,
      /\*\*(.+?)\*\*/,  # Bold text often contains key points
      /^\d+\.\s*(.+?)(?:\n|$)/m  # Numbered lists
    ]

    patterns.each do |pattern|
      content.scan(pattern) do |match|
        insight = match[0].strip
        insights << insight if insight.length > 20  # 의미있는 길이만
      end
    end

    insights.uniq
  end

  def extract_recommendations(content)
    recommendations = []

    # 추천사항 패턴
    patterns = [
      /(?:recommend|suggest|should|could|consider|try):\s*(.+?)(?:\n|$)/i,
      /(?:to improve|to fix|to resolve):\s*(.+?)(?:\n|$)/i
    ]

    patterns.each do |pattern|
      content.scan(pattern) do |match|
        recommendations << match[0].strip
      end
    end

    recommendations.uniq
  end

  def extract_code_snippets(response)
    content = response["choices"][0]["message"]["content"]
    code_blocks = []

    # 다양한 언어의 코드 블록 추출
    languages = [ "python", "excel", "vba", "sql", "r" ]

    languages.each do |lang|
      content.scan(/```#{lang}\n(.*?)```/m) do |match|
        code_blocks << {
          language: lang,
          code: match[0].strip,
          purpose: extract_code_purpose(content, match[0])
        }
      end
    end

    code_blocks
  end

  def extract_code_purpose(content, code)
    # 코드 블록 앞의 설명 찾기
    code_index = content.index(code)
    return nil unless code_index

    # 코드 앞 200자 검색
    prefix = content[([ code_index - 200, 0 ].max)...code_index]

    # 마지막 문장 추출
    sentences = prefix.split(/[.!?]/)
    sentences.last&.strip
  end

  def extract_visualization_suggestions(content)
    visualizations = []

    # 시각화 관련 키워드와 패턴
    viz_patterns = [
      /(?:create|generate|make|plot|draw)\s+(?:a\s+)?(\w+\s+(?:chart|graph|plot|diagram))/i,
      /(\w+\s+(?:chart|graph|plot|visualization))\s+would\s+be\s+(?:useful|helpful|good)/i
    ]

    viz_patterns.each do |pattern|
      content.scan(pattern) do |match|
        visualizations << match[0].strip
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

      Generate Python code to accomplish this task. Requirements:
      1. Use pandas for data manipulation
      2. Include proper error handling with try-except blocks
      3. Add comments explaining each step
      4. Handle missing data appropriately
      5. If visualization is needed, use matplotlib or seaborn
      6. Optimize for large files (use chunking if needed)
      7. Return results in a format that can be saved back to Excel

      The code should be production-ready and handle edge cases.
    PROMPT
  end

  def extract_code_from_response(response)
    content = response["choices"][0]["message"]["content"]

    # 모든 코드 블록 추출
    all_code_blocks = extract_code_snippets(response)

    # Python 코드 우선
    python_code = all_code_blocks.find { |block| block[:language] == "python" }

    # 설명 추출 (코드 블록 제외)
    explanation = content.gsub(/```[\w]*.*?```/m, "").strip

    {
      code: python_code&.dig(:code) || "",
      explanation: explanation,
      dependencies: extract_dependencies(python_code&.dig(:code) || ""),
      all_code_blocks: all_code_blocks,
      model_used: response["model"]
    }
  end

  def extract_dependencies(code)
    dependencies = Set.new

    # import 문 분석
    code.scan(/^import\s+(\w+)/) do |match|
      dependencies.add(match[0])
    end

    code.scan(/^from\s+(\w+)(?:\.\w+)*\s+import/) do |match|
      dependencies.add(match[0])
    end

    # 표준 라이브러리 제외
    standard_libs = %w[os sys json datetime collections itertools functools re math random]
    dependencies.reject { |dep| standard_libs.include?(dep) }.to_a
  end

  def extract_suggestions(response)
    content = response["choices"][0]["message"]["content"]
    suggestions = []

    # 다양한 제안 형식 추출
    patterns = [
      /^\d+\.\s*(.+?)(?:\n|$)/m,  # 번호 목록
      /^[-•]\s*(.+?)(?:\n|$)/m,   # 불릿 포인트
      /(?:you can|try|consider)\s+(.+?)(?:\.|$)/i  # 제안 문구
    ]

    patterns.each do |pattern|
      content.scan(pattern) do |match|
        suggestion = match[0].strip
        suggestions << suggestion if suggestion.length > 10
      end
    end

    suggestions.uniq.first(10)  # 최대 10개 제안
  end

  def create_data_summary(excel_file)
    {
      filename: excel_file.filename,
      sheets: excel_file.analysis_result.dig("file_analysis", "sheets") || [],
      total_rows: excel_file.analysis_result.dig("file_analysis", "summary", "total_rows") || 0,
      total_columns: excel_file.analysis_result.dig("file_analysis", "summary", "total_columns") || 0,
      has_errors: excel_file.errors_found > 0,
      error_types: excel_file.analysis_result.dig("file_analysis", "errors")&.map { |e| e["error_type"] } || [],
      file_size: excel_file.file_size,
      formula_count: excel_file.analysis_result.dig("file_analysis", "summary", "total_formulas") || 0
    }
  end
end
