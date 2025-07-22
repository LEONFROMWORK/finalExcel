# frozen_string_literal: true

class AiTierService
  # AI Tier 정의 - OpenRouter 모델 기반
  TIERS = {
    basic: {
      name: "Basic",
      models: {
        chat: "openai/gpt-3.5-turbo",
        analysis: "anthropic/claude-3-haiku",
        code: "openai/gpt-3.5-turbo"
      },
      features: {
        max_file_size: 10.megabytes,
        max_tokens: 2048,
        analysis_depth: "basic",
        code_generation: false,
        batch_processing: false,
        priority_queue: false
      },
      credit_multiplier: 1.0,  # 기본 크레딧 소비율
      description: "기본적인 Excel 분석과 간단한 질문 답변"
    },

    pro: {
      name: "Pro",
      models: {
        chat: "anthropic/claude-3-sonnet",
        analysis: "anthropic/claude-3-sonnet",
        code: "anthropic/claude-3-opus"
      },
      features: {
        max_file_size: 50.megabytes,
        max_tokens: 4096,
        analysis_depth: "advanced",
        code_generation: true,
        batch_processing: true,
        priority_queue: true
      },
      credit_multiplier: 0.8,  # 20% 크레딧 할인
      description: "고급 분석, 코드 생성, 복잡한 데이터 처리"
    },

    enterprise: {
      name: "Enterprise",
      models: {
        chat: "anthropic/claude-3-opus",
        analysis: "anthropic/claude-3-opus",
        code: "anthropic/claude-3-opus",
        vision: "google/gemini-pro-vision"  # 이미지 분석용
      },
      features: {
        max_file_size: 500.megabytes,
        max_tokens: 8192,
        analysis_depth: "deep",
        code_generation: true,
        batch_processing: true,
        priority_queue: true,
        custom_models: true,
        api_access: true
      },
      credit_multiplier: 0.5,  # 50% 크레딧 할인
      description: "최고 수준의 AI 모델, 무제한 기능, API 액세스"
    }
  }.freeze

  # 작업별 기본 크레딧 비용
  BASE_COSTS = {
    file_analysis: 10,
    ai_message: 5,
    code_generation: 20,
    batch_analysis: 50,
    image_analysis: 15,
    vba_analysis: 25,
    template_creation: 15
  }.freeze

  def initialize(user)
    @user = user
    @tier = determine_user_tier
  end

  def current_tier
    TIERS[@tier]
  end

  def available_models
    current_tier[:models]
  end

  def can_use_feature?(feature)
    current_tier[:features][feature] == true
  end

  def calculate_credit_cost(operation, options = {})
    base_cost = BASE_COSTS[operation] || 10

    # Tier별 할인 적용
    cost = base_cost * current_tier[:credit_multiplier]

    # 추가 비용 요소
    if options[:file_size] && options[:file_size] > 10.megabytes
      cost *= 1.5  # 대용량 파일 추가 비용
    end

    if options[:urgent]
      cost *= 2  # 긴급 처리 추가 비용
    end

    cost.round
  end

  def get_model_for_task(task)
    model_key = case task
    when :chat, :consultation
                  :chat
    when :analysis, :excel_analysis
                  :analysis
    when :code, :code_generation
                  :code
    when :image, :vision
                  :vision
    else
                  :chat
    end

    current_tier[:models][model_key] || current_tier[:models][:chat]
  end

  def validate_request(operation, options = {})
    errors = []

    # 파일 크기 제한 확인
    if options[:file_size] && options[:file_size] > current_tier[:features][:max_file_size]
      errors << "File size exceeds tier limit (#{current_tier[:features][:max_file_size] / 1.megabyte}MB)"
    end

    # 기능 사용 가능 여부 확인
    if operation == :code_generation && !can_use_feature?(:code_generation)
      errors << "Code generation is not available in #{current_tier[:name]} tier"
    end

    if operation == :batch_analysis && !can_use_feature?(:batch_processing)
      errors << "Batch processing is not available in #{current_tier[:name]} tier"
    end

    # 크레딧 확인
    required_credits = calculate_credit_cost(operation, options)
    if @user.credits < required_credits
      errors << "Insufficient credits (required: #{required_credits}, available: #{@user.credits})"
    end

    {
      valid: errors.empty?,
      errors: errors,
      required_credits: required_credits
    }
  end

  def process_with_tier(operation, &block)
    validation = validate_request(operation)

    unless validation[:valid]
      return {
        success: false,
        errors: validation[:errors]
      }
    end

    # 크레딧 차감
    @user.decrement!(:credits, validation[:required_credits])

    # 작업 실행
    begin
      result = yield

      {
        success: true,
        result: result,
        credits_used: validation[:required_credits],
        remaining_credits: @user.credits
      }
    rescue StandardError => e
      # 오류 시 크레딧 복구
      @user.increment!(:credits, validation[:required_credits])

      {
        success: false,
        error: e.message
      }
    end
  end

  def upgrade_tier(new_tier)
    return false unless TIERS.key?(new_tier)
    return false if new_tier == @tier

    # 여기서 결제 처리 등을 수행
    @user.update!(
      ai_tier: new_tier,
      tier_upgraded_at: Time.current
    )

    @tier = new_tier
    true
  end

  def tier_comparison
    TIERS.map do |key, tier|
      {
        key: key,
        name: tier[:name],
        description: tier[:description],
        features: tier[:features],
        models: tier[:models].transform_values { |m| m.split("/").last },
        credit_multiplier: tier[:credit_multiplier],
        is_current: key == @tier
      }
    end
  end

  private

  def determine_user_tier
    # User 모델에 ai_tier 필드가 있다면 사용
    if @user.respond_to?(:ai_tier) && @user.ai_tier.present?
      @user.ai_tier.to_sym
    else
      # 없으면 크레딧 양이나 가입일 기준으로 자동 결정
      if @user.admin?
        :enterprise
      elsif @user.credits > 1000 || @user.created_at < 3.months.ago
        :pro
      else
        :basic
      end
    end
  end

  class << self
    def tier_features_table
      # Vue 컴포넌트에서 사용할 수 있는 형식으로 변환
      TIERS.transform_values do |tier|
        {
          name: tier[:name],
          description: tier[:description],
          features: [
            { name: "최대 파일 크기", value: "#{tier[:features][:max_file_size] / 1.megabyte}MB" },
            { name: "최대 토큰", value: tier[:features][:max_tokens] },
            { name: "분석 깊이", value: tier[:features][:analysis_depth] },
            { name: "코드 생성", value: tier[:features][:code_generation] ? "✓" : "✗" },
            { name: "배치 처리", value: tier[:features][:batch_processing] ? "✓" : "✗" },
            { name: "우선 처리", value: tier[:features][:priority_queue] ? "✓" : "✗" },
            { name: "API 액세스", value: tier[:features][:api_access] ? "✓" : "✗" }
          ],
          models: tier[:models],
          credit_discount: "#{((1 - tier[:credit_multiplier]) * 100).to_i}%"
        }
      end
    end

    def recommended_tier_for_usage(monthly_requests, average_file_size)
      if monthly_requests > 1000 || average_file_size > 50.megabytes
        :enterprise
      elsif monthly_requests > 100 || average_file_size > 10.megabytes
        :pro
      else
        :basic
      end
    end
  end
end
