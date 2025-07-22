# frozen_string_literal: true

# 기존 시스템과 새로운 OpenRouter LLM을 통합하는 서비스
class UnifiedAiService
  def initialize(user_or_tier = :basic)
    if user_or_tier.is_a?(Symbol)
      # Tier가 직접 전달된 경우
      @tier = user_or_tier
      @user = nil
      @tier_service = AiTierService.new(nil)
    else
      # User 객체가 전달된 경우
      @user = user_or_tier
      @tier_service = AiTierService.new(user_or_tier)
      @tier = @tier_service.get_user_tier
    end
    @llm_service = OpenRouterLLMService.new
  end
  
  # Excel 파일 분석 요청 (기존 시스템 + 새로운 LLM)
  def analyze_excel_file(excel_file, user_query = nil)
    # Tier 검증
    validation = @tier_service.validate_request(
      :file_analysis,
      file_size: excel_file.file_size
    )
    
    return validation unless validation[:valid]
    
    # Tier에 따른 모델 선택
    model = @tier_service.get_model_for_task(:analysis)
    
    # 크레딧 차감하면서 실행
    @tier_service.process_with_tier(:file_analysis) do
      # 1. 기존 Python 서비스로 기본 분석
      basic_analysis = perform_basic_analysis(excel_file)
      
      # 2. LLM으로 심층 분석 (Pro/Enterprise tier만)
      if @tier_service.can_use_feature?(:analysis_depth) && user_query
        llm_analysis = @llm_service.analyze_excel_with_context(
          excel_file,
          user_query,
          model: model
        )
        
        # 결과 병합
        merge_analysis_results(basic_analysis, llm_analysis)
      else
        basic_analysis
      end
    end
  end
  
  # AI 상담 메시지 처리
  def process_chat_message(chat_session, message)
    # Tier 검증
    validation = @tier_service.validate_request(:ai_message)
    return validation unless validation[:valid]
    
    # Tier에 따른 모델 선택
    model = @tier_service.get_model_for_task(:chat)
    
    # Excel 컨텍스트 가져오기
    excel_context = nil
    if chat_session.excel_file
      excel_context = build_excel_context(chat_session.excel_file)
    end
    
    # 크레딧 차감하면서 실행
    @tier_service.process_with_tier(:ai_message) do
      # LLM 호출
      response = @llm_service.process_consultation_message(
        chat_session,
        message,
        excel_context
      )
      
      # 메시지 저장
      chat_message = chat_session.messages.create!(
        content: response[:content],
        is_ai: true,
        metadata: {
          model_used: response[:model_used],
          suggestions: response[:suggestions],
          code_snippets: response[:code_snippets],
          usage: response[:usage]
        }
      )
      
      # 백그라운드로 추가 처리
      if response[:code_snippets].any? && @tier_service.can_use_feature?(:code_generation)
        ExecuteCodeSuggestionsJob.perform_later(chat_message.id)
      end
      
      response
    end
  end
  
  # 코드 생성 요청
  def generate_code(excel_file, request)
    # Basic tier는 코드 생성 불가
    unless @tier_service.can_use_feature?(:code_generation)
      return {
        success: false,
        error: 'Code generation requires Pro or Enterprise tier'
      }
    end
    
    validation = @tier_service.validate_request(:code_generation)
    return validation unless validation[:valid]
    
    model = @tier_service.get_model_for_task(:code)
    
    @tier_service.process_with_tier(:code_generation) do
      result = @llm_service.generate_analysis_code(excel_file, request)
      
      # Enterprise tier는 코드 자동 실행
      if @tier_service.current_tier[:key] == :enterprise
        execution_result = execute_generated_code(result[:code], excel_file)
        result[:execution] = execution_result
      end
      
      result
    end
  end
  
  # 배치 분석 (여러 파일 동시 분석)
  def batch_analyze(excel_files, analysis_type)
    unless @tier_service.can_use_feature?(:batch_processing)
      return {
        success: false,
        error: 'Batch processing requires Pro or Enterprise tier'
      }
    end
    
    validation = @tier_service.validate_request(
      :batch_analysis,
      file_count: excel_files.size
    )
    return validation unless validation[:valid]
    
    @tier_service.process_with_tier(:batch_analysis) do
      results = excel_files.map do |file|
        {
          file_id: file.id,
          filename: file.filename,
          analysis: analyze_excel_file(file, analysis_type)
        }
      end
      
      {
        total_files: excel_files.size,
        results: results,
        summary: generate_batch_summary(results)
      }
    end
  end
  
  # Tier 업그레이드
  def upgrade_to_tier(new_tier)
    current = @tier_service.current_tier
    target = AiTierService::TIERS[new_tier]
    
    return { success: false, error: 'Invalid tier' } unless target
    return { success: false, error: 'Already on this tier' } if current[:key] == new_tier
    
    # 여기서 결제 처리 로직 추가
    # ...
    
    if @tier_service.upgrade_tier(new_tier)
      {
        success: true,
        message: "Successfully upgraded to #{target[:name]} tier",
        new_features: target[:features]
      }
    else
      {
        success: false,
        error: 'Failed to upgrade tier'
      }
    end
  end
  
  # 현재 사용 가능한 기능 목록
  def available_features
    tier = @tier_service.current_tier
    
    {
      tier_name: tier[:name],
      models: tier[:models],
      features: tier[:features],
      credit_discount: "#{((1 - tier[:credit_multiplier]) * 100).to_i}%",
      remaining_credits: @user.credits
    }
  end
  
  private
  
  def perform_basic_analysis(excel_file)
    # 기존 Python 서비스 호출
    python_client = PythonServiceClient.new
    file_path = Rails.root.join('tmp', 'uploads', File.basename(excel_file.file_url))
    
    python_client.analyze_excel(file_path)
  end
  
  def build_excel_context(excel_file)
    {
      file_info: {
        filename: excel_file.filename,
        size: excel_file.file_size
      },
      analysis_result: excel_file.analysis_result,
      errors: excel_file.errors_found
    }
  end
  
  def merge_analysis_results(basic, llm)
    {
      basic_analysis: basic,
      ai_insights: llm[:insights],
      recommendations: llm[:recommendations],
      code_suggestions: llm[:code_suggestions],
      visualizations: llm[:visualizations],
      combined_summary: generate_combined_summary(basic, llm)
    }
  end
  
  def generate_combined_summary(basic, llm)
    {
      total_issues: basic['file_analysis']['summary']['total_errors'] || 0,
      ai_insights_count: llm[:insights].size,
      actionable_recommendations: llm[:recommendations].size,
      suggested_visualizations: llm[:visualizations].size,
      has_code_solutions: llm[:code_suggestions].any?
    }
  end
  
  def execute_generated_code(code, excel_file)
    # Jupyter 커널에서 코드 실행 (향후 구현)
    {
      status: 'pending',
      message: 'Code execution will be implemented with Jupyter kernel integration'
    }
  end
  
  def generate_batch_summary(results)
    successful = results.count { |r| r[:analysis][:success] }
    
    {
      total_processed: results.size,
      successful: successful,
      failed: results.size - successful,
      common_issues: extract_common_issues(results),
      aggregated_insights: aggregate_insights(results)
    }
  end
  
  def extract_common_issues(results)
    # 공통 문제점 추출 로직
    []
  end
  
  def aggregate_insights(results)
    # 인사이트 집계 로직
    []
  end
  
  public
  
  # Vision API를 사용한 이미지 분석
  def analyze_with_vision(prompt:, images: [], excel_context: nil)
    # Vision 가능한 모델 선택 (GPT-4V 또는 Claude)
    vision_models = {
      basic: 'openai/gpt-4-vision-preview',
      pro: 'anthropic/claude-3-sonnet',
      enterprise: 'anthropic/claude-3-opus'
    }
    
    model = vision_models[@tier] || vision_models[:basic]
    
    # 이미지를 base64로 인코딩
    encoded_images = images.map do |image_path|
      next unless File.exist?(image_path)
      
      {
        type: "image",
        source: {
          type: "base64",
          media_type: "image/#{File.extname(image_path)[1..-1]}",
          data: Base64.encode64(File.read(image_path))
        }
      }
    end.compact
    
    # OpenRouter API 호출
    response = @llm_service.chat(
      model: model,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            *encoded_images
          ]
        }
      ],
      temperature: 0.3,
      max_tokens: 2000
    )
    
    {
      success: true,
      content: response[:content],
      model: model,
      credits_used: calculate_vision_credits(encoded_images.size),
      vision_details: {
        images_analyzed: encoded_images.size,
        model_used: model
      }
    }
  rescue => e
    Rails.logger.error "Vision analysis failed: #{e.message}"
    { success: false, error: e.message }
  end
  
  # 사용자가 직접 프롬프트를 제공하는 일반적인 생성
  def generate_text(prompt:, max_tokens: 1000, temperature: 0.7)
    model = case @tier
            when :basic then 'openai/gpt-3.5-turbo'
            when :pro then 'anthropic/claude-3-sonnet'
            when :enterprise then 'anthropic/claude-3-opus'
            else 'openai/gpt-3.5-turbo'
            end
    
    response = @llm_service.chat(
      model: model,
      messages: [{ role: "user", content: prompt }],
      temperature: temperature,
      max_tokens: max_tokens
    )
    
    {
      success: true,
      content: response[:content],
      model: model,
      credits_used: calculate_text_credits(prompt.length + (response[:content]&.length || 0))
    }
  rescue => e
    Rails.logger.error "Text generation failed: #{e.message}"
    { success: false, error: e.message }
  end
  
  private
  
  def calculate_vision_credits(image_count)
    # Vision API는 더 많은 크레딧 소비
    base_credit = 0.05
    image_credit = 0.02 * image_count
    
    total = base_credit + image_credit
    
    # Tier별 할인 적용
    case @tier
    when :pro then total * 0.8
    when :enterprise then total * 0.5
    else total
    end
  end
  
  def calculate_text_credits(total_chars)
    # 텍스트 기반 크레딧 계산
    tokens = total_chars / 4.0  # 대략적인 토큰 계산
    base_credit = tokens * 0.00001
    
    # Tier별 할인 적용
    case @tier
    when :pro then base_credit * 0.8
    when :enterprise then base_credit * 0.5
    else base_credit
    end
  end
end